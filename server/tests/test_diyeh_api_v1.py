import json
import os
import shutil

import pytest

from conftest import SERVER_DIR
from diyeh_api_v1 import create_app

RATES_SRC = os.path.join(SERVER_DIR, "data", "diyeh_rates_1405.json")
URL = "/api/v1/diyeh-rates"


def _touch_later(path):
    """Make sure the file's mtime differs even on coarse filesystem clocks."""
    st = os.stat(path)
    os.utime(path, ns=(st.st_atime_ns, st.st_mtime_ns + 10_000_000_000))


def _write_json(path, data):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False)
    _touch_later(path)


@pytest.fixture
def env(tmp_path):
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    rates = data_dir / "diyeh_rates_1405.json"
    shutil.copy(RATES_SRC, rates)
    config = tmp_path / "server_config.json"
    _write_json(config, {"current_rates_file": "data/diyeh_rates_1405.json", "cache_max_age_seconds": 3600})
    app = create_app(str(config))
    app.testing = True
    return {"client": app.test_client(), "rates": rates, "config": config, "data_dir": data_dir}


def _load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def test_returns_rates_with_cache_headers(env):
    resp = env["client"].get(URL)
    assert resp.status_code == 200
    assert resp.headers["Content-Type"] == "application/json; charset=utf-8"
    assert resp.headers["Cache-Control"] == "public, max-age=3600"
    assert resp.headers.get("ETag")
    body = resp.get_json()
    assert body["year"] == 1405
    assert body["full_diyeh_toman"] == 2_100_000_000
    # Persian text is sent as UTF-8, not \u escapes.
    assert "دیه کامل" in resp.get_data(as_text=True)


def test_pending_items_are_still_served(env):
    # Filtering pending items is the app's job; the server sends the whole file.
    body = env["client"].get(URL).get_json()
    pending = {it["id"] for it in body["items"] if it["status"] == "pending"}
    assert pending == {
        "wound_harese", "wound_damiye", "wound_motalaheme",
        "wound_samhagh", "wound_mozehe", "wound_hasheme",
    }


def test_conditional_request_returns_304(env):
    etag = env["client"].get(URL).headers["ETag"]
    resp = env["client"].get(URL, headers={"If-None-Match": etag})
    assert resp.status_code == 304
    assert resp.get_data() == b""


def test_rate_change_is_served_without_restart(env):
    first = env["client"].get(URL)
    data = _load(env["rates"])
    data["full_diyeh_toman"] = 2_500_000_000
    _write_json(env["rates"], data)

    resp = env["client"].get(URL, headers={"If-None-Match": first.headers["ETag"]})
    assert resp.status_code == 200
    assert resp.get_json()["full_diyeh_toman"] == 2_500_000_000
    assert resp.headers["ETag"] != first.headers["ETag"]


def test_invalid_edit_keeps_last_valid_version(env):
    env["client"].get(URL)
    with open(env["rates"], "w", encoding="utf-8") as fh:
        fh.write('{"year": 1405, broken')
    _touch_later(env["rates"])
    resp = env["client"].get(URL)
    assert resp.status_code == 200
    assert resp.get_json()["full_diyeh_toman"] == 2_100_000_000


def test_invalid_fraction_keeps_last_valid_version(env):
    env["client"].get(URL)
    data = _load(env["rates"])
    data["items"][1]["fraction"] = "0.05"
    _write_json(env["rates"], data)
    body = env["client"].get(URL).get_json()
    assert body["items"][1]["fraction"] == "1/20"


def test_config_switch_to_new_year_file(env):
    env["client"].get(URL)
    data = _load(env["rates"])
    data["year"] = 1406
    data["full_diyeh_toman"] = 2_500_000_000
    _write_json(env["data_dir"] / "diyeh_rates_1406.json", data)
    _write_json(env["config"], {"current_rates_file": "data/diyeh_rates_1406.json", "cache_max_age_seconds": 3600})

    body = env["client"].get(URL).get_json()
    assert body["year"] == 1406
    assert body["full_diyeh_toman"] == 2_500_000_000


def test_cache_max_age_comes_from_config(env):
    _write_json(env["config"], {"current_rates_file": "data/diyeh_rates_1405.json", "cache_max_age_seconds": 600})
    assert env["client"].get(URL).headers["Cache-Control"] == "public, max-age=600"


def test_missing_file_at_startup_returns_503(tmp_path):
    config = tmp_path / "server_config.json"
    _write_json(config, {"current_rates_file": "data/nope.json"})
    client = create_app(str(config)).test_client()
    resp = client.get(URL)
    assert resp.status_code == 503
    assert resp.headers["Cache-Control"] == "no-store"
    assert client.get("/api/v1/health").status_code == 503


def test_health_ok(env):
    resp = env["client"].get("/api/v1/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok", "year": 1405, "updated_at": "1405-08-22", "schema_version": 1}


def test_unknown_path_and_method(env):
    assert env["client"].get("/api/v1/nothing").status_code == 404
    assert env["client"].post(URL).status_code == 405
