import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';

/// Placeholder until this tab is built in a later phase.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.tabHome)),
      body: const Center(child: Text(AppStrings.comingSoon)),
    );
  }
}
