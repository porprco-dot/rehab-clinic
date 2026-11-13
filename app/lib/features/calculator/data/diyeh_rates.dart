import 'dart:convert';

import '../../../core/math/fraction.dart';

/// The only rates-file structure this app version understands.
const supportedSchemaVersion = 1;

enum CalcType { fixed, relativeToBase, percentOfBase }

enum ItemCategory { nafs, organ }

class QuantitySpec {
  final String label;
  final int min;
  final int max;
  const QuantitySpec({required this.label, required this.min, required this.max});
}

class PercentSpec {
  final String label;
  final int min;
  final int max;
  const PercentSpec({required this.label, required this.min, required this.max});
}

class DiyehItem {
  final String id;
  final String groupId;
  final ItemCategory category;
  final String title;
  final String? shortTitle; // label when used as a base option
  final CalcType calcType;
  final Fraction? fraction; // fixed
  final Fraction? multiplier; // relativeToBase
  final List<String> baseOptions; // relativeToBase / percentOfBase
  final String? baseLabel;
  final PercentSpec? percentInput; // percentOfBase
  final QuantitySpec? quantity;
  final bool haramApplicable;
  final String? article;
  final String? sourceUrl;
  final bool approved;
  final String? note;

  const DiyehItem({
    required this.id,
    required this.groupId,
    required this.category,
    required this.title,
    this.shortTitle,
    required this.calcType,
    this.fraction,
    this.multiplier,
    this.baseOptions = const [],
    this.baseLabel,
    this.percentInput,
    this.quantity,
    required this.haramApplicable,
    this.article,
    this.sourceUrl,
    required this.approved,
    this.note,
  });

  bool get needsBase => calcType != CalcType.fixed;

  String get baseOptionLabel => shortTitle ?? title;
}

class DiyehGroup {
  final String id;
  final String title;
  final int order;
  const DiyehGroup({required this.id, required this.title, required this.order});
}

class PaymentOption {
  final String id;
  final String title;
  final String description;
  final List<Fraction> installments;
  const PaymentOption({
    required this.id,
    required this.title,
    required this.description,
    required this.installments,
  });
}

class PaymentSchedule {
  final String article;
  final String periodLabel;
  final List<PaymentOption> options;
  const PaymentSchedule({required this.article, required this.periodLabel, required this.options});
}

/// Female-victim rule. [thresholdScope] and [reductionMode] stay null until
/// the legal decision is made; while null the app does not offer a gender
/// choice (see [DiyehRates.femaleRuleReady]).
class FemaleRule {
  final Fraction thresholdFraction;
  final Fraction organFactor;
  final Fraction nafsFactor;
  final String? thresholdScope;
  final String? reductionMode;
  const FemaleRule({
    required this.thresholdFraction,
    required this.organFactor,
    required this.nafsFactor,
    this.thresholdScope,
    this.reductionMode,
  });
}

/// Keys of [DiyehRates.texts]. All user-facing legal texts come from the file.
class TextKeys {
  static const currencyLabel = 'currency_label';
  static const disclaimerFooter = 'disclaimer_footer';
  static const help = 'help';
  static const haramQuestion = 'haram_question';
  static const genderQuestion = 'gender_question';
  static const insuranceNote = 'insurance_note';
  static const multipleInjuriesNote = 'multiple_injuries_note';
  static const paymentQuestion = 'payment_question';
  static const sourceButton = 'source_button';

  static const required = [
    currencyLabel,
    disclaimerFooter,
    help,
    haramQuestion,
    multipleInjuriesNote,
    paymentQuestion,
    sourceButton,
  ];
}

class DiyehRates {
  final int schemaVersion;
  final int year;
  final BigInt fullDiyehToman;
  final Fraction haramExtraFraction;
  final String updatedAt;
  final FemaleRule femaleRule;
  final PaymentSchedule paymentSchedule;
  final Map<String, String> texts;
  final List<DiyehGroup> groups; // sorted by order
  final List<DiyehItem> allItems; // including pending

  DiyehRates({
    required this.schemaVersion,
    required this.year,
    required this.fullDiyehToman,
    required this.haramExtraFraction,
    required this.updatedAt,
    required this.femaleRule,
    required this.paymentSchedule,
    required this.texts,
    required this.groups,
    required this.allItems,
  }) : _byId = {for (final it in allItems) it.id: it};

  final Map<String, DiyehItem> _byId;

  /// Only approved items are ever shown or used in the app.
  List<DiyehItem> get approvedItems => allItems.where((it) => it.approved).toList();

  DiyehItem? approvedItem(String id) {
    final it = _byId[id];
    return (it != null && it.approved) ? it : null;
  }

  String text(String key) => texts[key] ?? '';

  /// The female rule is applied only after the pending legal decision fills
  /// both fields in the server file AND an app version implements it.
  /// This version implements none, so gender is never offered yet.
  bool get femaleRuleReady => false;

  /// Newer-than comparison used to choose between cached and bundled data.
  bool isNewerOrSameAs(DiyehRates other) {
    if (year != other.year) return year > other.year;
    return updatedAt.compareTo(other.updatedAt) >= 0;
  }

  static DiyehRates parseJson(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('root must be an object');
    }
    return fromMap(decoded);
  }

  static DiyehRates fromMap(Map<String, dynamic> m) {
    final schema = _int(m, 'schema_version');
    if (schema != supportedSchemaVersion) {
      throw FormatException('unsupported schema_version $schema');
    }
    final full = _int(m, 'full_diyeh_toman');
    if (full <= 0) throw const FormatException('full_diyeh_toman must be positive');

    final fr = _map(m, 'female_rule');
    final femaleRule = FemaleRule(
      thresholdFraction: _fraction(fr, 'threshold_fraction'),
      organFactor: _fraction(fr, 'organ_factor'),
      nafsFactor: _fraction(fr, 'nafs_factor'),
      thresholdScope: fr['threshold_scope'] as String?,
      reductionMode: fr['reduction_mode'] as String?,
    );

    final ps = _map(m, 'payment_schedule');
    final options = _list(ps, 'options').map((o) {
      final om = _asMap(o, 'payment option');
      final inst = _list(om, 'installments').map((f) => _parseFraction(f, 'installment')).toList();
      if (inst.isEmpty || inst.fold(Fraction.zero, (a, b) => a + b) != Fraction.one) {
        throw const FormatException('installments must sum to 1');
      }
      return PaymentOption(
        id: _str(om, 'id'),
        title: _str(om, 'title'),
        description: _str(om, 'description'),
        installments: inst,
      );
    }).toList();
    final schedule = PaymentSchedule(
      article: _str(ps, 'article'),
      periodLabel: _str(ps, 'period_label'),
      options: options,
    );

    final textsRaw = _map(m, 'texts');
    final texts = <String, String>{};
    textsRaw.forEach((k, v) {
      if (v is String) texts[k] = v;
    });
    for (final key in TextKeys.required) {
      if ((texts[key] ?? '').isEmpty) throw FormatException('missing text $key');
    }

    final groups = _list(m, 'groups').map((g) {
      final gm = _asMap(g, 'group');
      return DiyehGroup(id: _str(gm, 'id'), title: _str(gm, 'title'), order: _int(gm, 'order'));
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final groupIds = groups.map((g) => g.id).toSet();

    final items = _list(m, 'items').map((i) => _parseItem(_asMap(i, 'item'))).toList();
    final ids = <String>{};
    for (final it in items) {
      if (!ids.add(it.id)) throw FormatException('duplicate item id ${it.id}');
      if (!groupIds.contains(it.groupId)) throw FormatException('unknown group for ${it.id}');
    }
    final byId = {for (final it in items) it.id: it};
    for (final it in items.where((it) => it.needsBase)) {
      if (it.baseOptions.isEmpty) throw FormatException('${it.id}: base_options empty');
      for (final b in it.baseOptions) {
        final base = byId[b];
        if (base == null || base.calcType != CalcType.fixed) {
          throw FormatException('${it.id}: invalid base $b');
        }
      }
    }

    return DiyehRates(
      schemaVersion: schema,
      year: _int(m, 'year'),
      fullDiyehToman: BigInt.from(full),
      haramExtraFraction: _fraction(m, 'haram_extra_fraction'),
      updatedAt: _str(m, 'updated_at'),
      femaleRule: femaleRule,
      paymentSchedule: schedule,
      texts: texts,
      groups: groups,
      allItems: items,
    );
  }

  static DiyehItem _parseItem(Map<String, dynamic> m) {
    final id = _str(m, 'id');
    final calcType = switch (m['calc_type']) {
      'fixed' => CalcType.fixed,
      'relative_to_base' => CalcType.relativeToBase,
      'percent_of_base' => CalcType.percentOfBase,
      _ => throw FormatException('$id: unknown calc_type'),
    };
    final category = switch (m['category']) {
      'nafs' => ItemCategory.nafs,
      'organ' => ItemCategory.organ,
      _ => throw FormatException('$id: unknown category'),
    };
    final status = m['status'];
    if (status != 'approved' && status != 'pending') {
      throw FormatException('$id: unknown status');
    }

    QuantitySpec? quantity;
    final q = m['quantity'];
    if (q != null) {
      final qm = _asMap(q, '$id.quantity');
      final min = _int(qm, 'min'), max = _int(qm, 'max');
      if (min < 1 || max < min) throw FormatException('$id: bad quantity range');
      quantity = QuantitySpec(label: _str(qm, 'label'), min: min, max: max);
    }

    PercentSpec? percent;
    if (calcType == CalcType.percentOfBase) {
      final pm = _map(m, 'percent_input');
      final min = _int(pm, 'min'), max = _int(pm, 'max');
      if (min < 1 || max < min || max > 100) throw FormatException('$id: bad percent range');
      percent = PercentSpec(label: _str(pm, 'label'), min: min, max: max);
    }

    return DiyehItem(
      id: id,
      groupId: _str(m, 'group'),
      category: category,
      title: _str(m, 'title'),
      shortTitle: m['short_title'] as String?,
      calcType: calcType,
      fraction: calcType == CalcType.fixed ? _fraction(m, 'fraction') : null,
      multiplier: calcType == CalcType.relativeToBase ? _fraction(m, 'multiplier') : null,
      baseOptions: calcType == CalcType.fixed
          ? const []
          : _list(m, 'base_options').map((e) => e is String ? e : throw FormatException('$id: base')).toList(),
      baseLabel: calcType == CalcType.fixed ? null : _str(m, 'base_label'),
      percentInput: percent,
      quantity: quantity,
      haramApplicable: m['haram_applicable'] == true,
      article: m['article'] as String?,
      sourceUrl: m['source_url'] as String?,
      approved: status == 'approved',
      note: m['note'] as String?,
    );
  }

  // ---- small strict readers ----

  static Map<String, dynamic> _asMap(Object? v, String what) {
    if (v is Map<String, dynamic>) return v;
    throw FormatException('$what must be an object');
  }

  static Map<String, dynamic> _map(Map<String, dynamic> m, String key) => _asMap(m[key], key);

  static List<dynamic> _list(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is List && v.isNotEmpty) return v;
    throw FormatException('$key must be a non-empty list');
  }

  static String _str(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is String && v.trim().isNotEmpty) return v;
    throw FormatException('$key must be a non-empty string');
  }

  static int _int(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is int) return v;
    throw FormatException('$key must be an integer');
  }

  static Fraction _fraction(Map<String, dynamic> m, String key) => _parseFraction(m[key], key);

  static Fraction _parseFraction(Object? v, String what) {
    final f = Fraction.tryParse(v);
    if (f == null) throw FormatException('$what: invalid fraction $v');
    return f;
  }
}
