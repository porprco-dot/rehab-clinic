import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoghoogh_darman/features/calculator/data/rates_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers.dart';

final endpoint = Uri.parse('https://example.test/api/v1/diyeh-rates');

http.Response jsonResponse(String body, {String etag = '"v2"'}) => http.Response.bytes(
      utf8.encode(body),
      200,
      headers: {'content-type': 'application/json', 'etag': etag}, // no charset on purpose
    );

RatesRepository repo(MockClient client, MemoryRatesCache cache, {Uri? uri}) => RatesRepository(
      client: client,
      endpoint: uri ?? endpoint,
      cache: cache,
      loadBundled: () async => bundledJson(),
    );

void main() {
  final rate25 = modifiedJson((m) => m['full_diyeh_toman'] = 2500000000);

  test('first run with no cache uses bundled data', () async {
    final r = repo(MockClient((_) async => throw const SocketException('offline')), MemoryRatesCache());
    final s = await r.loadLocal();
    expect(s.origin, RatesOrigin.bundled);
    expect(s.rates.fullDiyehToman, BigInt.from(2100000000));
  });

  test('server rate change reaches the app and is cached (no app update)', () async {
    final cache = MemoryRatesCache();
    final r = repo(MockClient((_) async => jsonResponse(rate25)), cache);
    final s = await r.refresh();
    expect(s!.origin, RatesOrigin.network);
    expect(s.rates.fullDiyehToman, BigInt.from(2500000000));
    expect(cache.value!.etag, '"v2"');
    // Persian text survives even without charset in the header.
    expect(s.rates.approvedItem('nafs')!.title, 'دیه کامل (فوت)');

    // Next launch, offline: the cached 2.5 billion is used.
    final offline = repo(MockClient((_) async => throw const SocketException('offline')), cache);
    final local = await offline.loadLocal();
    expect(local.origin, RatesOrigin.cache);
    expect(local.rates.fullDiyehToman, BigInt.from(2500000000));
    expect(await offline.refresh(), isNull);
  });

  test('sends cached ETag and keeps data on 304', () async {
    final cache = MemoryRatesCache(CachedRates(rate25, '"v2"'));
    String? sentEtag;
    final r = repo(MockClient((req) async {
      sentEtag = req.headers['If-None-Match'];
      return http.Response('', 304);
    }), cache);
    expect(await r.refresh(), isNull);
    expect(sentEtag, '"v2"');
    expect(cache.writes, 0);
  });

  test('invalid server data is ignored and not cached', () async {
    final cache = MemoryRatesCache();
    for (final bad in [
      '{broken',
      modifiedJson((m) => m['schema_version'] = 2),
      modifiedJson((m) => (m['items'] as List)[0]['fraction'] = '0.5'),
    ]) {
      final r = repo(MockClient((_) async => jsonResponse(bad)), cache);
      expect(await r.refresh(), isNull);
    }
    expect(cache.writes, 0);
  });

  test('server error and timeout are ignored', () async {
    final cache = MemoryRatesCache();
    expect(await repo(MockClient((_) async => http.Response('x', 503)), cache).refresh(), isNull);
    final slow = RatesRepository(
      client: MockClient((_) => Future.delayed(const Duration(seconds: 5), () => jsonResponse(rate25))),
      endpoint: endpoint,
      cache: cache,
      loadBundled: () async => bundledJson(),
      timeout: const Duration(milliseconds: 50),
    );
    expect(await slow.refresh(), isNull);
    expect(cache.writes, 0);
  });

  test('corrupt cache falls back to bundled', () async {
    final r = repo(MockClient((_) async => http.Response('', 500)), MemoryRatesCache(const CachedRates('{oops', null)));
    expect((await r.loadLocal()).origin, RatesOrigin.bundled);
  });

  test('bundled data newer than an old cache wins (after an app update)', () async {
    final old = modifiedJson((m) {
      m['year'] = 1404;
      m['full_diyeh_toman'] = 1600000000;
    });
    final r = repo(MockClient((_) async => http.Response('', 500)), MemoryRatesCache(CachedRates(old, null)));
    final s = await r.loadLocal();
    expect(s.origin, RatesOrigin.bundled);
    expect(s.rates.year, 1405);
  });

  test('no server address configured: never touches the network', () async {
    var called = false;
    final r = RatesRepository(
      client: MockClient((_) async {
        called = true;
        return jsonResponse(rate25);
      }),
      endpoint: null,
      cache: MemoryRatesCache(),
      loadBundled: () async => bundledJson(),
    );
    expect(await r.refresh(), isNull);
    expect(called, isFalse);
  });
}
