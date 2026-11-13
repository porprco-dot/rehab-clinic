import 'package:flutter/foundation.dart';

import '../data/diyeh_rates.dart';
import '../data/rates_repository.dart';
import '../domain/diyeh_calculator.dart';

class CalculatorController extends ChangeNotifier {
  CalculatorController(this.repository);

  final RatesRepository repository;

  RatesSnapshot? _snapshot;
  bool _loading = true;
  bool _failed = false;
  bool _refreshing = false;
  final List<InjuryEntry> _entries = [];
  bool _haramMonth = false;
  String? _paymentOptionId;
  int _nextKey = 0;

  RatesSnapshot? get snapshot => _snapshot;
  DiyehRates? get rates => _snapshot?.rates;
  bool get loading => _loading;
  bool get failed => _failed;
  bool get refreshing => _refreshing;
  List<InjuryEntry> get entries => List.unmodifiable(_entries);
  bool get haramMonth => _haramMonth;
  String? get paymentOptionId => _paymentOptionId;

  DiyehCalculator? get _calculator => rates == null ? null : DiyehCalculator(rates!);

  CalculationResult? get result => _calculator?.calculate(_entries, haramMonth: _haramMonth);

  bool get showHaramQuestion => _calculator?.needsHaramQuestion(_entries) ?? false;

  PaymentOption? get paymentOption {
    final r = rates;
    if (r == null || _paymentOptionId == null) return null;
    for (final o in r.paymentSchedule.options) {
      if (o.id == _paymentOptionId) return o;
    }
    return null;
  }

  /// Shows local data immediately, then checks the server in the background.
  Future<void> init() async {
    try {
      _snapshot = await repository.loadLocal();
    } on Object {
      _failed = true;
    }
    _loading = false;
    notifyListeners();
    if (!_failed) await refresh();
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    notifyListeners();
    try {
      final fresh = await repository.refresh();
      if (fresh != null) {
        _snapshot = fresh;
        _dropEntriesNoLongerAvailable();
      }
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  void addItem(DiyehItem item) {
    _entries.add(InjuryEntry.initial(_nextKey++, item));
    notifyListeners();
  }

  void updateEntry(InjuryEntry updated) {
    final i = _entries.indexWhere((e) => e.key == updated.key);
    if (i < 0) return;
    _entries[i] = updated;
    notifyListeners();
  }

  void removeEntry(int key) {
    _entries.removeWhere((e) => e.key == key);
    if (!showHaramQuestion) _haramMonth = false;
    notifyListeners();
  }

  void setHaramMonth(bool value) {
    _haramMonth = value;
    notifyListeners();
  }

  void setPaymentOption(String? id) {
    _paymentOptionId = id;
    notifyListeners();
  }

  /// After new server data, items that became pending or were removed are
  /// dropped so they can no longer be shown.
  void _dropEntriesNoLongerAvailable() {
    final r = rates!;
    _entries.removeWhere((e) => r.approvedItem(e.itemId) == null);
    if (paymentOption == null) _paymentOptionId = null;
    if (!showHaramQuestion) _haramMonth = false;
  }
}
