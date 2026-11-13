import 'package:flutter_test/flutter_test.dart';
import 'package:hoghoogh_darman/core/math/fraction.dart';

void main() {
  test('parses and normalizes', () {
    expect(Fraction.parse('10/100'), Fraction.fromInts(1, 10));
    expect(Fraction.parse('1'), Fraction.one);
    expect(Fraction.parse('2/3').toString(), '2/3');
  });

  test('rejects non-fraction text', () {
    for (final t in ['0.05', '1/0', ' 1/2', '1 / 2', '-1/2', '', '1/2/3', 'a']) {
      expect(Fraction.tryParse(t), isNull, reason: t);
    }
    expect(Fraction.tryParse(null), isNull);
    expect(Fraction.tryParse(0.5), isNull);
  });

  test('arithmetic is exact', () {
    // 12 front teeth (1/20) + 16 back teeth (1/40) = exactly 1
    final sum = Fraction.parse('1/20').timesInt(12) + Fraction.parse('1/40').timesInt(16);
    expect(sum, Fraction.one);
    expect(Fraction.parse('1/3') * Fraction.parse('3'), Fraction.one);
    expect(Fraction.parse('1/2') - Fraction.parse('1/3'), Fraction.fromInts(1, 6));
  });

  test('rounds half up', () {
    expect(Fraction.fromInts(5, 2).roundHalfUp(), BigInt.from(3));
    expect(Fraction.fromInts(7, 3).roundHalfUp(), BigInt.from(2));
    expect(Fraction.fromInts(8, 3).roundHalfUp(), BigInt.from(3));
    expect(Fraction.fromInts(2500000000, 15).roundHalfUp(), BigInt.from(166666667));
  });

  test('compare', () {
    expect(Fraction.parse('1/3') < Fraction.parse('7/20'), isTrue);
    expect(Fraction.parse('1/3') >= Fraction.parse('2/6'), isTrue);
  });
}
