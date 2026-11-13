import 'package:flutter/material.dart';

import '../core/strings/app_strings.dart';
import '../features/account/account_screen.dart';
import '../features/calculator/presentation/calculator_controller.dart';
import '../features/calculator/presentation/calculator_screen.dart';
import '../features/cases/cases_screen.dart';
import '../features/home/home_screen.dart';

/// Bottom navigation with the app's four tabs. New tabs plug in here.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.calculatorController});

  final CalculatorController calculatorController;

  /// Phase 1 only has the calculator, so the app opens on it.
  static const initialTab = 2;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = MainShell.initialTab;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const CasesScreen(),
      CalculatorScreen(controller: widget.calculatorController),
      const AccountScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: AppStrings.tabHome),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: AppStrings.tabCases),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: AppStrings.tabCalculator),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: AppStrings.tabAccount),
        ],
      ),
    );
  }
}
