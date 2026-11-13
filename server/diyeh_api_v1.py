"""Diyeh rates API (version 1).

Endpoints:
    GET /api/v1/diyeh-rates  -> current rates JSON (ETag + Cache-Control)
    GET /api/v1/health       -> service health

The rates file named in server_config.json is re-checked on every request,
so editing the JSON (or switching the config to a new year's file) takes
effect without restarting the service. If an edited file is invalid, the
last valid version keeps being served and the error is logged.

Run locally:   flask --app diyeh_api_v1 run
Production:    gunicorn diyeh_api_v1:app   (see deploy/diyeh-api.service)
"""

import hashlib
import json
import logging
import os
import threading

from flask import Flask, Response, jsonify, request

from validate_rates_v1 import RatesValidationError, load_and_validate

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CONFIG_PATH = os.path.join(BASE_DIR, "server_config.json")
DEFAULT_CACHE_MAX_AGE = 3600

logger = logging.getLogger("diyeh_api")


class RatesStore:
    """Holds the last valid rates payload and reloads it when files change."""

    def __init__(self, config_path):
        self.config_path = config_path
        self._lock = threading.Lock()
        self._config_sig = None
        self._config = None
        self._rates_sig = None
        self._payload = None  # bytes
        self._etag = None
        self._summary = None  # dict with year etc.

    @staticmethod
    def _signature(path):
        st = os.stat(path)
        return (path, st.st_mtime_ns, st.st_size)

    def _reload_config(self):
        try:
            sig = self._signature(self.config_path)
        except OSError as exc:
            if self._config is None:
                logger.error("cannot read config %s: %s", self.config_path, exc)
            return
        if sig == self._config_sig:
            return
        try:
            with open(self.config_path, "rb") as fh:
                cfg = json.loads(fh.read().decode("utf-8"))
            rates_file = cfg["current_rates_file"]
            if not isinstance(rates_file, str) or not rates_file:
                raise ValueError("current_rates_file must be a non-empty string")
            max_age = cfg.get("cache_max_age_seconds", DEFAULT_CACHE_MAX_AGE)
            if not isinstance(max_age, int) or isinstance(max_age, bool) or max_age < 0:
                raise ValueError("cache_max_age_seconds must be a non-negative integer")
        except (OSError, ValueError, KeyError, UnicodeDecodeError) as exc:
            logger.error("invalid config %s, keeping previous: %s", self.config_path, exc)
            self._config_sig = sig  # do not re-log on every request
            return
        config_dir = os.path.dirname(os.path.abspath(self.config_path))
        self._config = {
            "rates_path": os.path.normpath(os.path.join(config_dir, rates_file)),
            "cache_max_age": max_age,
        }
        self._config_sig = sig
        logger.info("config loaded: rates file %s", self._config["rates_path"])

    def _reload_rates(self):
        if self._config is None:
            return
        path = self._config["rates_path"]
        try:
            sig = self._signature(path)
        except OSError as exc:
            missing_sig = ("missing", path)
            if self._rates_sig != missing_sig:  # log once, not on every request
                self._rates_sig = missing_sig
                logger.error("cannot read rates file %s, keeping previous: %s", path, exc)
            return
        if sig == self._rates_sig:
            return
        self._rates_sig = sig
        try:
            with open(path, "rb") as fh:
                data = load_and_validate(fh.read())
        except OSError as exc:
            logger.error("cannot read rates file %s, keeping previous: %s", path, exc)
            return
        except RatesValidationError as exc:
            logger.error("invalid rates file %s, keeping previous version:", path)
            for e in exc.errors:
                logger.error("  - %s", e)
            return
        payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self._payload = payload
        self._etag = hashlib.sha256(payload).hexdigest()[:32]
        self._summary = {
            "year": data["year"],
            "updated_at": data["updated_at"],
            "schema_version": data["schema_version"],
        }
        logger.info(
            "rates loaded: %s (year %s, full diyeh %s)",
            path,
            data["year"],
            data["full_diyeh_toman"],
        )

    def current(self):
        """Return (payload_bytes, etag, cache_max_age, summary) or None if nothing valid yet."""
        with self._lock:
            self._reload_config()
            self._reload_rates()
            if self._payload is None:
                return None
            return self._payload, self._etag, self._config["cache_max_age"], self._summary


def create_app(config_path=None):
    app = Flask(__name__)
    app.json.ensure_ascii = False
    store = RatesStore(config_path or os.environ.get("DIYEH_CONFIG", DEFAULT_CONFIG_PATH))
    app.extensions["diyeh_rates_store"] = store

    @app.get("/api/v1/diyeh-rates")
    def diyeh_rates():
        current = store.current()
        if current is None:
            resp = jsonify(error="rates_unavailable")
            resp.status_code = 503
            resp.headers["Cache-Control"] = "no-store"
            return resp
        payload, etag, max_age, _ = current
        # Explicit charset: Dart's http package otherwise decodes the body as Latin-1.
        resp = Response(payload, content_type="application/json; charset=utf-8")
        resp.set_etag(etag)
        resp.headers["Cache-Control"] = f"public, max-age={max_age}"
        return resp.make_conditional(request)

    @app.get("/api/v1/health")
    def health():
        current = store.current()
        if current is None:
            resp = jsonify(status="error", detail="rates_unavailable")
            resp.status_code = 503
        else:
            resp = jsonify(status="ok", **current[3])
        resp.headers["Cache-Control"] = "no-store"
        return resp

    @app.errorhandler(404)
    def not_found(_exc):
        return jsonify(error="not_found"), 404

    @app.errorhandler(405)
    def method_not_allowed(_exc):
        return jsonify(error="method_not_allowed"), 405

    @app.after_request
    def security_headers(resp):
        resp.headers["X-Content-Type-Options"] = "nosniff"
        return resp

    return app


logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
app = create_app()
