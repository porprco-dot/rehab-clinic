import '../../../core/math/fraction.dart';
import '../data/diyeh_rates.dart';

/// One injury the user added. The same item may be added more than once
/// (e.g. two teeth broken by different percentages).
class InjuryEntry {
  final int key; // stable identity for the UI list
  final String itemId;
  final int quantity;
  final String? baseId;
  final int? percent;

  const InjuryEntry({
    required this.key,
    required this.itemId,
    this.quantity = 1,
    this.baseId,
    this.percent,
  });

  InjuryEntry copyWith({int? quantity, String? baseId, int? percent}) => InjuryEntry(
        key: key,
        itemId: itemId,
        quantity: quantity ?? this.quantity,
        baseId: baseId ?? this.baseId,
        percent: percent ?? this.percent,
      );

  /// A new entry with sensible defaults for [item].
  factory InjuryEntry.initial(int key, DiyehItem item) => InjuryEntry(
        key: key,
        itemId: item.id,
        quantity: item.quantity?.min ?? 1,
        baseId: item.needsBase ? item.baseOptions.first : null,
        percent: item.percentInput?.min,
      );
}

class EntryResult {
  final InjuryEntry entry;
  final DiyehItem item;
  final Fraction fraction; // share of full diyeh, incl. haram extra
  final BigInt amountToman;
  final bool haramApplied;
  const EntryResult({
    required this.entry,
    required this.item,
    required this.fraction,
    required this.amountToman,
    required this.haramApplied,
  });
}

class Installment {
  final int yearNumber; // 1-based lunar year
  final BigInt amountToman;
  const Installment(this.yearNumber, this.amountToman);
}

class CalculationResult {
  final List<EntryResult> entries;
  final Fraction totalFraction;
  final BigInt totalToman;
  final bool showMultipleInjuriesNote;
  const CalculationResult({
    required this.entries,
    required this.totalFraction,
    required this.totalToman,
    required this.showMultipleInjuriesNote,
  });

  bool get isEmpty => entries.isEmpty;
}

/// Pure calculation logic; all numbers come from [DiyehRates].
class DiyehCalculator {
  final DiyehRates rates;
  const DiyehCalculator(this.rates);

  /// Share of the full diyeh for one entry, before the haram extra.
  /// Returns null when the entry refers to an item that is not approved
  /// (or no longer exists) in the current rates.
  Fraction? baseFraction(InjuryEntry e) {
    final item = rates.approvedItem(e.itemId);
    if (item == null) return null;
    final qty = _clampQuantity(item, e.quantity);
    switch (item.calcType) {
      case CalcType.fixed:
        return item.fraction!.timesInt(qty);
      case CalcType.relativeToBase:
        final base = _base(item, e.baseId);
        if (base == null) return null;
        return base.fraction! * item.multiplier! * Fraction.fromInts(qty);
      case CalcType.percentOfBase:
        final base = _base(item, e.baseId);
        if (base == null) return null;
        final spec = item.percentInput!;
        final pct = (e.percent ?? spec.min).clamp(spec.min, spec.max);
        return base.fraction! * Fraction.fromInts(pct, 100) * Fraction.fromInts(qty);
    }
  }

  /// [haramMonth]: injury and death both happened in a sacred month.
  /// Applies only to items marked haram_applicable (i.e. nafs).
  CalculationResult calculate(List<InjuryEntry> entries, {bool haramMonth = false}) {
    final results = <EntryResult>[];
    var total = Fraction.zero;
    for (final e in entries) {
      final item = rates.approvedItem(e.itemId);
      final f = baseFraction(e);
      if (item == null || f == null) continue;
      final haram = haramMonth && item.haramApplicable;
      final withHaram = haram ? f * (Fraction.one + rates.haramExtraFraction) : f;
      total = total + withHaram;
      results.add(EntryResult(
        entry: e,
        item: item,
        fraction: withHaram,
        amountToman: toToman(withHaram),
        haramApplied: haram,
      ));
    }
    return CalculationResult(
      entries: results,
      totalFraction: total,
      // Rounded once from the exact sum, not by adding rounded rows.
      totalToman: toToman(total),
      showMultipleInjuriesNote: results.length > 1,
    );
  }

  BigInt toToman(Fraction share) =>
      (share * Fraction(rates.fullDiyehToman)).roundHalfUp();

  /// Splits [totalToman] by the option's yearly shares. The last installment
  /// absorbs rounding so the installments always add up to the total.
  static List<Installment> schedule(BigInt totalToman, PaymentOption option) {
    final out = <Installment>[];
    var paid = BigInt.zero;
    for (var i = 0; i < option.installments.length; i++) {
      final isLast = i == option.installments.length - 1;
      final amount = isLast
          ? totalToman - paid
          : (option.installments[i] * Fraction(totalToman)).roundHalfUp();
      paid += amount;
      out.add(Installment(i + 1, amount));
    }
    return out;
  }

  /// True if any entry needs the sacred-month question.
  bool needsHaramQuestion(List<InjuryEntry> entries) =>
      entries.any((e) => rates.approvedItem(e.itemId)?.haramApplicable ?? false);

  DiyehItem? _base(DiyehItem item, String? baseId) {
    final id = (baseId != null && item.baseOptions.contains(baseId)) ? baseId : item.baseOptions.first;
    final base = rates.approvedItem(id);
    return (base != null && base.calcType == CalcType.fixed) ? base : null;
  }

  static int _clampQuantity(DiyehItem item, int q) {
    final spec = item.quantity;
    if (spec == null) return 1;
    return q.clamp(spec.min, spec.max);
  }
}
