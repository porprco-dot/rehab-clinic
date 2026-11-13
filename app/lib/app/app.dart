import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/strings/app_strings.dart';
import '../features/calculator/presentation/calculator_controller.dart';
import 'main_shell.dart';
import 'theme.dart';

class HoghooghDarmanApp extends StatelessWidget {
  const HoghooghDarmanApp({super.key, required this.calculatorController});

  final CalculatorController calculatorController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      // Persian locale → right-to-left layout everywhere.
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: MainShell(calculatorController: calculatorController),
    );
  }
}
