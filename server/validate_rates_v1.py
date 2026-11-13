"""Validation for diyeh rates files (schema_version 1).

Usable as a module (``validate_rates(data)``) and as a command-line tool:

    python3 validate_rates_v1.py data/diyeh_rates_1405.json

Exit code 0 means the file is valid; otherwise errors are printed.
"""

import json
import re
import sys
from fractions import Fraction

SUPPORTED_SCHEMA_VERSION = 1

_FRACTION_RE = re.compile(r"^(\d+)(?:/(\d+))?$")

CALC_TYPES = {"fixed", "relative_to_base", "percent_of_base"}
STATUSES = {"approved", "pending"}
CATEGORIES = {"nafs", "organ"}
THRESHOLD_SCOPES = {None, "total", "per_item"}
REDUCTION_MODES = {None, "whole", "excess_only"}


class RatesValidationError(ValueError):
    """Raised when a rates file does not match the expected structure."""

    def __init__(self, errors):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def parse_fraction(value):
    """Parse a string fraction like "1/20" or "1" exactly. Returns Fraction or None."""
    if not isinstance(value, str):
        return None
    match = _FRACTION_RE.match(value)
    if not match:
        return None
    numerator = int(match.group(1))
    denominator = int(match.group(2)) if match.group(2) is not None else 1
    if denominator == 0:
        return None
    return Fraction(numerator, denominator)


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _is_nonempty_str(value):
    return isinstance(value, str) and value.strip() != ""


def validate_rates(data):
    """Return a list of error messages (empty list means valid)."""
    errors = []

    def err(msg):
        errors.append(msg)

    def check_fraction(path, value, allow_zero=False, max_one=True):
        f = parse_fraction(value)
        if f is None:
            err(f"{path}: کسر نامعتبر {value!r} (نمونه‌ی درست: \"1/20\")")
            return None
        if not allow_zero and f == 0:
            err(f"{path}: کسر نباید صفر باشد")
        if max_one and f > 1:
            err(f"{path}: کسر نباید بیشتر از ۱ باشد")
        return f

    if not isinstance(data, dict):
        return ["ریشه‌ی فایل باید یک شیء JSON باشد"]

    if data.get("schema_version") != SUPPORTED_SCHEMA_VERSION:
        err(f"schema_version باید {SUPPORTED_SCHEMA_VERSION} باشد")

    year = data.get("year")
    if not _is_int(year) or not 1300 <= year <= 1600:
        err("year باید سال شمسی (عدد صحیح) باشد")

    full = data.get("full_diyeh_toman")
    if not _is_int(full) or full <= 0:
        err("full_diyeh_toman باید عدد صحیح مثبت باشد (بدون ممیز و جداکننده)")

    check_fraction("haram_extra_fraction", data.get("haram_extra_fraction"))

    if not _is_nonempty_str(data.get("updated_at")):
        err("updated_at باید پر باشد")

    # female_rule
    fr = data.get("female_rule")
    if not isinstance(fr, dict):
        err("female_rule باید شیء باشد")
    else:
        for key in ("threshold_fraction", "organ_factor", "nafs_factor"):
            check_fraction(f"female_rule.{key}", fr.get(key))
        if fr.get("threshold_scope") not in THRESHOLD_SCOPES:
            err("female_rule.threshold_scope باید null یا \"total\" یا \"per_item\" باشد")
        if fr.get("reduction_mode") not in REDUCTION_MODES:
            err("female_rule.reduction_mode باید null یا \"whole\" یا \"excess_only\" باشد")

    # payment_schedule
    ps = data.get("payment_schedule")
    if not isinstance(ps, dict) or not isinstance(ps.get("options"), list) or not ps["options"]:
        err("payment_schedule.options باید فهرست غیرخالی باشد")
    else:
        seen = set()
        for i, opt in enumerate(ps["options"]):
            path = f"payment_schedule.options[{i}]"
            if not isinstance(opt, dict):
                err(f"{path}: باید شیء باشد")
                continue
            oid = opt.get("id")
            if not _is_nonempty_str(oid) or oid in seen:
                err(f"{path}.id خالی یا تکراری است")
            seen.add(oid)
            if not _is_nonempty_str(opt.get("title")):
                err(f"{path}.title خالی است")
            inst = opt.get("installments")
            if not isinstance(inst, list) or not inst:
                err(f"{path}.installments باید فهرست غیرخالی باشد")
                continue
            parts = [check_fraction(f"{path}.installments[{j}]", v) for j, v in enumerate(inst)]
            if all(p is not None for p in parts) and sum(parts) != 1:
                err(f"{path}.installments: جمع کسرها باید ۱ باشد")

    # texts
    texts = data.get("texts")
    if not isinstance(texts, dict) or not texts:
        err("texts باید شیء غیرخالی باشد")
    else:
        for key, value in texts.items():
            if not _is_nonempty_str(value):
                err(f"texts.{key} باید متن غیرخالی باشد")

    # groups
    groups = data.get("groups")
    group_ids = set()
    if not isinstance(groups, list) or not groups:
        err("groups باید فهرست غیرخالی باشد")
    else:
        for i, g in enumerate(groups):
            if not isinstance(g, dict) or not _is_nonempty_str(g.get("id")) or not _is_nonempty_str(g.get("title")):
                err(f"groups[{i}]: id و title لازم است")
                continue
            if g["id"] in group_ids:
                err(f"groups[{i}]: id تکراری {g['id']!r}")
            group_ids.add(g["id"])
            if not _is_int(g.get("order")):
                err(f"groups[{i}].order باید عدد صحیح باشد")

    # items
    items = data.get("items")
    if not isinstance(items, list) or not items:
        err("items باید فهرست غیرخالی باشد")
        return errors

    by_id = {}
    for i, item in enumerate(items):
        if not isinstance(item, dict):
            err(f"items[{i}]: باید شیء باشد")
            continue
        iid = item.get("id")
        if not _is_nonempty_str(iid):
            err(f"items[{i}].id خالی است")
            continue
        if iid in by_id:
            err(f"items[{i}]: id تکراری {iid!r}")
        by_id[iid] = item

    for i, item in enumerate(items):
        if not isinstance(item, dict) or not _is_nonempty_str(item.get("id")):
            continue
        path = f"items[{i}] ({item['id']})"

        if item.get("group") not in group_ids:
            err(f"{path}.group در groups تعریف نشده")
        if item.get("category") not in CATEGORIES:
            err(f"{path}.category باید \"nafs\" یا \"organ\" باشد")
        if not _is_nonempty_str(item.get("title")):
            err(f"{path}.title خالی است")
        if item.get("status") not in STATUSES:
            err(f"{path}.status باید \"approved\" یا \"pending\" باشد")
        if not isinstance(item.get("haram_applicable"), bool):
            err(f"{path}.haram_applicable باید true یا false باشد")
        for key in ("short_title", "article", "source_url", "note"):
            value = item.get(key)
            if value is not None and not _is_nonempty_str(value):
                err(f"{path}.{key} باید متن یا null باشد")
        url = item.get("source_url")
        if isinstance(url, str) and not url.startswith("https://"):
            err(f"{path}.source_url باید با https:// شروع شود")

        quantity = item.get("quantity")
        if quantity is not None:
            if (
                not isinstance(quantity, dict)
                or not _is_int(quantity.get("min"))
                or not _is_int(quantity.get("max"))
                or not 1 <= quantity["min"] <= quantity["max"]
                or not _is_nonempty_str(quantity.get("label"))
            ):
                err(f"{path}.quantity باید null یا {{label, min, max}} با 1 <= min <= max باشد")

        calc_type = item.get("calc_type")
        if calc_type not in CALC_TYPES:
            err(f"{path}.calc_type نامعتبر است")
            continue

        if calc_type == "fixed":
            check_fraction(f"{path}.fraction", item.get("fraction"))
            continue

        # relative_to_base / percent_of_base
        bases = item.get("base_options")
        if not isinstance(bases, list) or not bases:
            err(f"{path}.base_options باید فهرست غیرخالی باشد")
        else:
            for b in bases:
                base = by_id.get(b)
                if base is None:
                    err(f"{path}.base_options: آیتم {b!r} وجود ندارد")
                elif base.get("calc_type") != "fixed":
                    err(f"{path}.base_options: آیتم {b!r} باید از نوع fixed باشد")
                elif base.get("status") != "approved" and item.get("status") == "approved":
                    err(f"{path}.base_options: آیتم پایه‌ی {b!r} هنوز approved نیست")
        if not _is_nonempty_str(item.get("base_label")):
            err(f"{path}.base_label خالی است")

        if calc_type == "relative_to_base":
            check_fraction(f"{path}.multiplier", item.get("multiplier"))
        else:
            pi = item.get("percent_input")
            if (
                not isinstance(pi, dict)
                or not _is_int(pi.get("min"))
                or not _is_int(pi.get("max"))
                or not 1 <= pi["min"] <= pi["max"] <= 100
                or not _is_nonempty_str(pi.get("label"))
            ):
                err(f"{path}.percent_input باید {{label, min, max}} با 1 <= min <= max <= 100 باشد")

    return errors


def load_and_validate(raw_bytes):
    """Parse raw JSON bytes and validate. Returns parsed data or raises RatesValidationError."""
    try:
        data = json.loads(raw_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RatesValidationError([f"JSON نامعتبر: {exc}"]) from exc
    errors = validate_rates(data)
    if errors:
        raise RatesValidationError(errors)
    return data


def main(argv):
    if len(argv) != 2:
        print("استفاده: python3 validate_rates_v1.py <path-to-rates.json>")
        return 2
    try:
        with open(argv[1], "rb") as fh:
            data = load_and_validate(fh.read())
    except OSError as exc:
        print(f"خطا در خواندن فایل: {exc}")
        return 1
    except RatesValidationError as exc:
        print("فایل نامعتبر است:")
        for e in exc.errors:
            print(f"  - {e}")
        return 1
    approved = sum(1 for it in data["items"] if it["status"] == "approved")
    pending = len(data["items"]) - approved
    print(
        f"فایل معتبر است. سال {data['year']}، دیه‌ی کامل {data['full_diyeh_toman']:,} تومان، "
        f"{approved} آیتم approved و {pending} آیتم pending."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
