import copy
import json
import os
from fractions import Fraction

import pytest

from conftest import SERVER_DIR
from validate_rates_v1 import parse_fraction, validate_rates

RATES_PATH = os.path.join(SERVER_DIR, "data", "diyeh_rates_1405.json")


@pytest.fixture
def data():
    with open(RATES_PATH, encoding="utf-8") as fh:
        return json.load(fh)


def _item(data, item_id):
    return next(it for it in data["items"] if it["id"] == item_id)


def test_shipped_file_is_valid(data):
    assert validate_rates(data) == []


@pytest.mark.parametrize("text,expected", [("1", Fraction(1)), ("1/20", Fraction(1, 20)), ("10/100", Fraction(1, 10))])
def test_parse_fraction_ok(text, expected):
    assert parse_fraction(text) == expected


@pytest.mark.parametrize("text", ["0.05", "1/0", " 1/2", "1 / 2", "-1/2", "", None, 0.5, "1/2/3"])
def test_parse_fraction_rejects(text):
    assert parse_fraction(text) is None


def _errors_after(data, mutate):
    d = copy.deepcopy(data)
    mutate(d)
    return validate_rates(d)


def test_rejects_float_rate(data):
    assert _errors_after(data, lambda d: d.update(full_diyeh_toman=2.1e9))


def test_rejects_rate_as_string(data):
    assert _errors_after(data, lambda d: d.update(full_diyeh_toman="2,100,000,000"))


def test_rejects_duplicate_item_id(data):
    assert _errors_after(data, lambda d: d["items"].append(copy.deepcopy(d["items"][0])))


def test_rejects_unknown_group(data):
    assert _errors_after(data, lambda d: d["items"][0].update(group="eyes"))


def test_rejects_unknown_status(data):
    assert _errors_after(data, lambda d: d["items"][0].update(status="aproved"))


def test_rejects_fraction_above_one(data):
    assert _errors_after(data, lambda d: _item(d, "tooth_front").update(fraction="21/20"))


def test_rejects_installments_not_summing_to_one(data):
    assert _errors_after(data, lambda d: d["payment_schedule"]["options"][1].update(installments=["1/2", "1/3"]))


def test_rejects_unknown_base_option(data):
    assert _errors_after(data, lambda d: _item(d, "tooth_black").update(base_options=["tooth_front", "tooth_x"]))


def test_rejects_pending_base_for_approved_item(data):
    def mutate(d):
        _item(d, "tooth_back").update(status="pending")
    assert _errors_after(data, mutate)


def test_rejects_bad_percent_input(data):
    assert _errors_after(data, lambda d: _item(d, "tooth_crown_partial")["percent_input"].update(max=150))


def test_rejects_bad_female_mode(data):
    assert _errors_after(data, lambda d: d["female_rule"].update(threshold_scope="sum"))


def test_accepts_decided_female_modes(data):
    def mutate(d):
        d["female_rule"].update(threshold_scope="total", reduction_mode="whole")
    assert _errors_after(data, mutate) == []


def test_rejects_http_source(data):
    assert _errors_after(data, lambda d: _item(d, "tooth_front").update(source_url="http://example.com"))
