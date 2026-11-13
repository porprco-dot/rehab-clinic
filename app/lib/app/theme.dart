import 'package:flutter/material.dart';

const _seed = Color(0xFF1F6F78);
const _fontFamily = 'Vazirmatn';

ThemeData _build(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    fontFamily: _fontFamily,
    useMaterial3: true,
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
  );
}

final ThemeData lightTheme = _build(Brightness.light);
final ThemeData darkTheme = _build(Brightness.dark);
