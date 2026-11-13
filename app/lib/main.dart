import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'app/app.dart';
import 'core/config/api_config.dart';
import 'features/calculator/data/rates_repository.dart';
import 'features/calculator/presentation/calculator_controller.dart';

const bundledRatesAsset = 'assets/data/diyeh_rates_default.json';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = RatesRepository(
    client: http.Client(),
    endpoint: ApiConfig.diyehRatesUri,
    cache: SharedPrefsRatesCache(),
    loadBundled: () => rootBundle.loadString(bundledRatesAsset),
    timeout: ApiConfig.requestTimeout,
  );
  final controller = CalculatorController(repository)..init();
  runApp(HoghooghDarmanApp(calculatorController: controller));
}
