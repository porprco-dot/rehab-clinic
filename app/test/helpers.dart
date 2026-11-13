import 'dart:convert';
import 'dart:io';

import 'package:hoghoogh_darman/features/calculator/data/diyeh_rates.dart';
import 'package:hoghoogh_darman/features/calculator/data/rates_repository.dart';

const bundledPath = 'assets/data/diyeh_rates_default.json';

String bundledJson() => File(bundledPath).readAsStringSync();

Map<String, dynamic> bundledMap() => jsonDecode(bundledJson()) as Map<String, dynamic>;

/// The bundled file with selected top-level fields changed.
String modifiedJson(void Function(Map<String, dynamic> m) change) {
  final m = bundledMap();
  change(m);
  return jsonEncode(m);
}

DiyehRates ratesWithFull(int toman) =>
    DiyehRates.parseJson(modifiedJson((m) => m['full_diyeh_toman'] = toman));

class MemoryRatesCache implements RatesCache {
  CachedRates? value;
  int writes = 0;
  MemoryRatesCache([this.value]);

  @override
  Future<CachedRates?> read() async => value;

  @override
  Future<void> write(CachedRates v) async {
    value = v;
    writes++;
  }
}
