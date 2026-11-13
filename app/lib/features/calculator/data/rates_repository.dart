import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'diyeh_rates.dart';

/// Where the rates currently in use came from.
enum RatesOrigin { network, cache, bundled }

class RatesSnapshot {
  final DiyehRates rates;
  final RatesOrigin origin;
  const RatesSnapshot(this.rates, this.origin);
}

/// Persistent storage for the last valid server response.
abstract class RatesCache {
  Future<CachedRates?> read();
  Future<void> write(CachedRates value);
}

class CachedRates {
  final String body;
  final String? etag;
  const CachedRates(this.body, this.etag);
}

class SharedPrefsRatesCache implements RatesCache {
  static const _bodyKey = 'diyeh_rates_body_v1';
  static const _etagKey = 'diyeh_rates_etag_v1';

  @override
  Future<CachedRates?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final body = prefs.getString(_bodyKey);
    if (body == null) return null;
    return CachedRates(body, prefs.getString(_etagKey));
  }

  @override
  Future<void> write(CachedRates value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bodyKey, value.body);
    if (value.etag != null) {
      await prefs.setString(_etagKey, value.etag!);
    } else {
      await prefs.remove(_etagKey);
    }
  }
}

/// Loads rates with this priority: server → cache → bundled default.
///
/// * [loadLocal] never touches the network, so the screen opens instantly
///   and works offline.
/// * [refresh] asks the server (conditionally, with the cached ETag) and
///   returns new rates only when they changed and are valid.
class RatesRepository {
  final http.Client client;
  final Uri? endpoint;
  final RatesCache cache;
  final Future<String> Function() loadBundled;
  final Duration timeout;

  RatesRepository({
    required this.client,
    required this.endpoint,
    required this.cache,
    required this.loadBundled,
    this.timeout = const Duration(seconds: 10),
  });

  Future<RatesSnapshot> loadLocal() async {
    final bundled = DiyehRates.parseJson(await loadBundled());
    final cached = await _readCachedRates();
    // A newer app version may ship newer bundled data than an old cache.
    if (cached != null && cached.isNewerOrSameAs(bundled)) {
      return RatesSnapshot(cached, RatesOrigin.cache);
    }
    return RatesSnapshot(bundled, RatesOrigin.bundled);
  }

  /// Returns fresh rates, or null when unchanged, unreachable or invalid.
  Future<RatesSnapshot?> refresh() async {
    final uri = endpoint;
    if (uri == null) return null;
    try {
      final cached = await cache.read();
      final headers = <String, String>{'Accept': 'application/json'};
      if (cached?.etag != null) headers['If-None-Match'] = cached!.etag!;

      final resp = await client.get(uri, headers: headers).timeout(timeout);
      if (resp.statusCode == 304) {
        return null;
      }
      if (resp.statusCode != 200) return null;

      // Decode as UTF-8 regardless of headers (Persian text).
      final body = utf8.decode(resp.bodyBytes);
      final rates = DiyehRates.parseJson(body); // throws if invalid
      await cache.write(CachedRates(body, resp.headers['etag']));
      return RatesSnapshot(rates, RatesOrigin.network);
    } on Object {
      // Offline, timeout, bad JSON, unsupported schema...: keep current data.
      return null;
    }
  }

  Future<DiyehRates?> _readCachedRates() async {
    try {
      final cached = await cache.read();
      if (cached == null) return null;
      return DiyehRates.parseJson(cached.body);
    } on Object {
      return null; // corrupt cache → fall back to bundled
    }
  }
}
