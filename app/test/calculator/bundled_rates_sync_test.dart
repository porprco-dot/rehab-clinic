import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// The offline default inside the app must match the server's current file.
/// If this fails: copy the server file named in server/server_config.json
/// to app/assets/data/diyeh_rates_default.json
void main() {
  test('bundled default equals the server\'s current rates file', () {
    final config = jsonDecode(File('../server/server_config.json').readAsStringSync()) as Map<String, dynamic>;
    final serverFile = File('../server/${config['current_rates_file']}');
    expect(jsonDecode(serverFile.readAsStringSync()), jsonDecode(bundledJson()));
  });
}
