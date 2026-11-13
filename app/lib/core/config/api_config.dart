/// Server address. Set at build time, never hard-coded:
///
///   flutter run --dart-define=DIYEH_API_BASE_URL=https://api.example.com
///
/// When empty, the app does not touch the network and uses the cached or
/// bundled rates only (useful until the production domain is ready).
class ApiConfig {
  static const String baseUrl = String.fromEnvironment('DIYEH_API_BASE_URL');

  static const Duration requestTimeout = Duration(seconds: 10);

  static Uri? get diyehRatesUri {
    if (baseUrl.isEmpty) return null;
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$base/api/v1/diyeh-rates');
  }
}
