import 'package:flutter_test/flutter_test.dart';
import 'package:hoghoogh_darman/core/format/persian_number.dart';

void main() {
  test('Persian digits with thousands separator', () {
    expect(formatPersianNumber(105000000), '۱۰۵٬۰۰۰٬۰۰۰');
    expect(formatPersianNumber(BigInt.from(2100000000)), '۲٬۱۰۰٬۰۰۰٬۰۰۰');
    expect(formatPersianNumber(999), '۹۹۹');
    expect(formatPersianNumber(1000), '۱٬۰۰۰');
    expect(formatPersianNumber(0), '۰');
  });

  test('formatToman', () {
    expect(formatToman(BigInt.from(105000000), 'تومان'), '۱۰۵٬۰۰۰٬۰۰۰ تومان');
  });

  test('toPersianDigits leaves other characters', () {
    expect(toPersianDigits('1405-08-22'), '۱۴۰۵-۰۸-۲۲');
  });

  test('formatPersianDate', () {
    expect(formatPersianDate('1405-08-22'), '\u2066۱۴۰۵/۰۸/۲۲\u2069');
  });
}
