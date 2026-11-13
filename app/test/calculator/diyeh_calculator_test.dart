import 'package:flutter_test/flutter_test.dart';
import 'package:hoghoogh_darman/core/math/fraction.dart';
import 'package:hoghoogh_darman/features/calculator/data/diyeh_rates.dart';
import 'package:hoghoogh_darman/features/calculator/domain/diyeh_calculator.dart';

import '../helpers.dart';

var _k = 0;
InjuryEntry e(String id, {int qty = 1, String? base, int? percent}) =>
    InjuryEntry(key: _k++, itemId: id, quantity: qty, baseId: base, percent: percent);

/// Spec section 6, amounts at 2,100,000,000 toman.
final specCases = <String, (List<InjuryEntry>, bool, int)>{
  'nafs, non-haram month': ([e('nafs')], false, 2100000000),
  'nafs, haram month': ([e('nafs')], true, 2800000000),
  'one front tooth': ([e('tooth_front')], false, 105000000),
  'one back tooth': ([e('tooth_back')], false, 52500000),
  '28 teeth (12 front + 16 back)': ([e('tooth_front', qty: 12), e('tooth_back', qty: 16)], false, 2100000000),
  'milk tooth': ([e('tooth_milk')], false, 21000000),
  'blackened front tooth': ([e('tooth_black', base: 'tooth_front')], false, 70000000),
  '50% of front tooth crown': ([e('tooth_crown_partial', base: 'tooth_front', percent: 50)], false, 52500000),
  'one finger': ([e('finger')], false, 210000000),
  'one non-thumb finger joint': ([e('finger_joint')], false, 70000000),
  'one thumb joint': ([e('thumb_joint')], false, 105000000),
  'paralysis of one finger': ([e('finger_paralysis')], false, 140000000),
  'one hand from wrist': ([e('hand_one')], false, 1050000000),
  'one foot from ankle': ([e('foot_one')], false, 1050000000),
  'paralysis of one lip': ([e('lip_paralysis')], false, 700000000),
};

void main() {
  final rates = DiyehRates.parseJson(bundledJson());
  final calc = DiyehCalculator(rates);

  test('bundled rate is 2,100,000,000', () {
    expect(rates.fullDiyehToman, BigInt.from(2100000000));
  });

  group('spec table at 2.1 billion', () {
    specCases.forEach((name, c) {
      test(name, () {
        final r = calc.calculate(c.$1, haramMonth: c.$2);
        expect(r.totalToman, BigInt.from(c.$3));
      });
    });
  });

  group('rate changed to 2.5 billion (no code change)', () {
    final calc25 = DiyehCalculator(ratesWithFull(2500000000));
    specCases.forEach((name, c) {
      test(name, () {
        final exact = Fraction.fromInts(c.$3) * Fraction.fromInts(2500000000, 2100000000);
        expect(calc25.calculate(c.$1, haramMonth: c.$2).totalToman, exact.roundHalfUp());
      });
    });
    test('example values', () {
      expect(calc25.calculate([e('tooth_front')]).totalToman, BigInt.from(125000000));
      expect(calc25.calculate([e('finger_paralysis')]).totalToman, BigInt.from(166666667));
    });
  });

  test('pending items are hidden and ignored', () {
    final ids = rates.approvedItems.map((i) => i.id).toSet();
    for (final id in ['wound_harese', 'wound_damiye', 'wound_motalaheme', 'wound_samhagh', 'wound_mozehe', 'wound_hasheme']) {
      expect(ids.contains(id), isFalse, reason: id);
      expect(rates.approvedItem(id), isNull);
    }
    expect(ids.length, 19);
    final r = calc.calculate([e('wound_mozehe'), e('tooth_front')]);
    expect(r.entries.length, 1);
    expect(r.totalToman, BigInt.from(105000000));
  });

  test('approving a pending item makes it usable', () {
    final r2 = DiyehRates.parseJson(modifiedJson((m) {
      for (final it in m['items'] as List) {
        if (it['id'] == 'wound_mozehe') it['status'] = 'approved';
      }
    }));
    expect(DiyehCalculator(r2).calculate([e('wound_mozehe')]).totalToman, BigInt.from(105000000));
  });

  test('haram extra applies only to nafs', () {
    final r = calc.calculate([e('nafs'), e('tooth_front')], haramMonth: true);
    expect(r.entries[0].amountToman, BigInt.from(2800000000));
    expect(r.entries[0].haramApplied, isTrue);
    expect(r.entries[1].amountToman, BigInt.from(105000000));
    expect(r.entries[1].haramApplied, isFalse);
    expect(calc.needsHaramQuestion([e('tooth_front')]), isFalse);
    expect(calc.needsHaramQuestion([e('nafs')]), isTrue);
  });

  test('multiple injuries are summed and flagged for the note', () {
    final r = calc.calculate([e('finger'), e('lip_paralysis')]);
    expect(r.totalToman, BigInt.from(910000000));
    expect(r.showMultipleInjuriesNote, isTrue);
    expect(calc.calculate([e('finger')]).showMultipleInjuriesNote, isFalse);
  });

  test('relative items follow the chosen base tooth', () {
    expect(calc.calculate([e('tooth_black', base: 'tooth_back')]).totalToman, BigInt.from(35000000));
    expect(calc.calculate([e('tooth_crown_full', base: 'tooth_back')]).totalToman, BigInt.from(52500000));
    expect(calc.calculate([e('tooth_milk_no_regrow', base: 'tooth_front')]).totalToman, BigInt.from(105000000));
    expect(calc.calculate([e('tooth_black', base: 'tooth_front', qty: 3)]).totalToman, BigInt.from(210000000));
  });

  test('quantity and percent are clamped to the file limits', () {
    expect(calc.calculate([e('tooth_front', qty: 99)]).totalToman, BigInt.from(1260000000)); // max 12
    expect(calc.calculate([e('finger', qty: 0)]).totalToman, BigInt.from(210000000)); // min 1
    expect(calc.calculate([e('tooth_crown_partial', base: 'tooth_front', percent: 150)]).totalToman, BigInt.from(105000000));
  });

  test('payment schedule installments add up to the total', () {
    final options = {for (final o in rates.paymentSchedule.options) o.id: o};
    final total = BigInt.from(2100000000);
    expect(DiyehCalculator.schedule(total, options['amd']!).map((i) => i.amountToman), [total]);
    expect(DiyehCalculator.schedule(total, options['shebh_amd']!).map((i) => i.amountToman),
        [BigInt.from(1050000000), BigInt.from(1050000000)]);
    expect(DiyehCalculator.schedule(total, options['khata_mahz']!).map((i) => i.amountToman),
        [BigInt.from(700000000), BigInt.from(700000000), BigInt.from(700000000)]);
    // Indivisible total: still sums exactly.
    final odd = BigInt.from(166666667);
    final parts = DiyehCalculator.schedule(odd, options['khata_mahz']!).map((i) => i.amountToman);
    expect(parts.fold(BigInt.zero, (a, b) => a + b), odd);
  });

  test('female rule is not offered until decided', () {
    expect(rates.femaleRule.thresholdScope, isNull);
    expect(rates.femaleRuleReady, isFalse);
  });

  group('parsing rejects invalid files', () {
    void rejects(String name, void Function(Map<String, dynamic>) change) {
      test(name, () => expect(() => DiyehRates.parseJson(modifiedJson(change)), throwsFormatException));
    }

    rejects('unsupported schema_version', (m) => m['schema_version'] = 2);
    rejects('decimal fraction', (m) => (m['items'] as List)[1]['fraction'] = '0.05');
    rejects('rate as text', (m) => m['full_diyeh_toman'] = '2100000000');
    rejects('unknown group', (m) => (m['items'] as List)[1]['group'] = 'x');
    rejects('missing footer text', (m) => (m['texts'] as Map).remove('disclaimer_footer'));
    rejects('installments not summing to 1', (m) => ((m['payment_schedule'] as Map)['options'] as List)[1]['installments'] = ['1/2']);
    test('not JSON', () => expect(() => DiyehRates.parseJson('{broken'), throwsFormatException));
  });
}
