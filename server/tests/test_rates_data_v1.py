"""Guards the shipped data against the expected results in spec section 6.

The app performs the real calculation; this test only makes sure that an
edit to the JSON file cannot silently break the agreed numbers.
"""

import json
import os
from fractions import Fraction

import pytest

from conftest import SERVER_DIR

RATES_PATH = os.path.join(SERVER_DIR, "data", "diyeh_rates_1405.json")


@pytest.fixture(scope="module")
def items():
    with open(RATES_PATH, encoding="utf-8") as fh:
        data = json.load(fh)
    return data, {it["id"]: it for it in data["items"]}


def _fraction(items_by_id, item_id, base=None, percent=None, qty=1):
    it = items_by_id[item_id]
    if it["calc_type"] == "fixed":
        f = Fraction(it["fraction"])
    elif it["calc_type"] == "relative_to_base":
        f = Fraction(items_by_id[base]["fraction"]) * Fraction(it["multiplier"])
    else:
        f = Fraction(items_by_id[base]["fraction"]) * Fraction(percent, 100)
    return f * qty


def _toman(fraction, rate):
    return int(fraction * rate + Fraction(1, 2))  # round half up


CASES = [
    ("nafs", lambda b, d: _fraction(b, "nafs"), 2_100_000_000),
    ("nafs_haram", lambda b, d: _fraction(b, "nafs") * (1 + Fraction(d["haram_extra_fraction"])), 2_800_000_000),
    ("tooth_front", lambda b, d: _fraction(b, "tooth_front"), 105_000_000),
    ("tooth_back", lambda b, d: _fraction(b, "tooth_back"), 52_500_000),
    ("28_teeth", lambda b, d: _fraction(b, "tooth_front", qty=12) + _fraction(b, "tooth_back", qty=16), 2_100_000_000),
    ("tooth_milk", lambda b, d: _fraction(b, "tooth_milk"), 21_000_000),
    ("tooth_black_front", lambda b, d: _fraction(b, "tooth_black", base="tooth_front"), 70_000_000),
    ("crown_50pct_front", lambda b, d: _fraction(b, "tooth_crown_partial", base="tooth_front", percent=50), 52_500_000),
    ("finger", lambda b, d: _fraction(b, "finger"), 210_000_000),
    ("finger_joint", lambda b, d: _fraction(b, "finger_joint"), 70_000_000),
    ("thumb_joint", lambda b, d: _fraction(b, "thumb_joint"), 105_000_000),
    ("finger_paralysis", lambda b, d: _fraction(b, "finger_paralysis"), 140_000_000),
    ("hand_one", lambda b, d: _fraction(b, "hand_one"), 1_050_000_000),
    ("foot_one", lambda b, d: _fraction(b, "foot_one"), 1_050_000_000),
    ("lip_paralysis", lambda b, d: _fraction(b, "lip_paralysis"), 700_000_000),
]


@pytest.mark.parametrize("name,frac_fn,expected", CASES, ids=[c[0] for c in CASES])
def test_spec_table_at_2_1_billion(items, name, frac_fn, expected):
    data, by_id = items
    assert data["full_diyeh_toman"] == 2_100_000_000
    assert _toman(frac_fn(by_id, data), data["full_diyeh_toman"]) == expected


@pytest.mark.parametrize("name,frac_fn,expected", CASES, ids=[c[0] for c in CASES])
def test_spec_table_scales_with_rate(items, name, frac_fn, expected):
    data, by_id = items
    exact = Fraction(expected) * Fraction(2_500_000_000, 2_100_000_000)
    assert _toman(frac_fn(by_id, data), 2_500_000_000) == int(exact + Fraction(1, 2))
