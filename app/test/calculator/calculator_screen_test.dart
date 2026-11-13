import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoghoogh_darman/app/app.dart';
import 'package:hoghoogh_darman/features/calculator/data/rates_repository.dart';
import 'package:hoghoogh_darman/features/calculator/presentation/calculator_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers.dart';

Future<CalculatorController> pumpApp(WidgetTester tester, {MockClient? client, MemoryRatesCache? cache}) async {
  // Phone width (400 logical px), tall enough to show the whole result.
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1200, 6000);
  addTearDown(tester.view.reset);
  final repository = RatesRepository(
    client: client ?? MockClient((_) async => http.Response('', 503)),
    endpoint: Uri.parse('https://example.test/api/v1/diyeh-rates'),
    cache: cache ?? MemoryRatesCache(),
    loadBundled: () async => bundledJson(),
  );
  final controller = CalculatorController(repository);
  await tester.runAsync(controller.init);
  await tester.pumpWidget(HoghooghDarmanApp(calculatorController: controller));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> pick(WidgetTester tester, String groupId, String itemId) async {
  await tester.tap(find.byKey(const Key('add_injury_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('group_$groupId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('pick_$itemId')));
  await tester.pumpAndSettle();
}

String totalText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('total_amount'))).data!;

void main() {
  testWidgets('opens on the calculator tab, RTL, with footer and status', (tester) async {
    await pumpApp(tester);
    expect(Directionality.of(tester.element(find.byKey(const Key('add_injury_button')))), TextDirection.rtl);
    expect(find.textContaining('۲٬۱۰۰٬۰۰۰٬۰۰۰ تومان'), findsOneWidget);
    expect(find.byKey(const Key('disclaimer_footer')), findsOneWidget);
    expect(find.text('ماشین‌حساب'), findsOneWidget); // tab label
  });

  testWidgets('one front tooth → ۱۰۵٬۰۰۰٬۰۰۰ تومان; quantity buttons work', (tester) async {
    await pumpApp(tester);
    await pick(tester, 'teeth', 'tooth_front');
    expect(totalText(tester), '۱۰۵٬۰۰۰٬۰۰۰ تومان');
    await tester.tap(find.byKey(const Key('qty_plus_0')));
    await tester.pumpAndSettle();
    expect(totalText(tester), '۲۱۰٬۰۰۰٬۰۰۰ تومان');
    expect(find.text('منبع'), findsOneWidget);
    expect(find.text('ماده ۶۱۶ ق.م.ا'), findsWidgets);
  });

  testWidgets('pending items never appear in the picker', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add_injury_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_head_wounds')), findsNothing);
    expect(find.text('موضحه'), findsNothing);
    expect(find.byKey(const Key('group_teeth')), findsOneWidget);
  });

  testWidgets('haram question only for nafs, adds one third', (tester) async {
    await pumpApp(tester);
    await pick(tester, 'finger', 'finger');
    expect(find.byKey(const Key('haram_switch')), findsNothing);
    await pick(tester, 'nafs', 'nafs');
    expect(find.byKey(const Key('haram_switch')), findsOneWidget);
    expect(totalText(tester), '۲٬۳۱۰٬۰۰۰٬۰۰۰ تومان');
    expect(find.byKey(const Key('multiple_injuries_note')), findsOneWidget);
    await tester.tap(find.byKey(const Key('haram_switch')));
    await tester.pumpAndSettle();
    expect(totalText(tester), '۳٬۰۱۰٬۰۰۰٬۰۰۰ تومان');
  });

  testWidgets('arsh note is shown for hand amputation', (tester) async {
    await pumpApp(tester);
    await pick(tester, 'hand_foot', 'hand_one');
    expect(totalText(tester), '۱٬۰۵۰٬۰۰۰٬۰۰۰ تومان');
    expect(find.textContaining('ارش مقدار اضافه'), findsOneWidget);
  });

  testWidgets('payment schedule: khata mahz in three equal parts', (tester) async {
    await pumpApp(tester);
    await pick(tester, 'nafs', 'nafs');
    await tester.tap(find.byKey(const Key('payment_khata_mahz')));
    await tester.pumpAndSettle();
    for (var y = 1; y <= 3; y++) {
      expect(tester.widget<Text>(find.byKey(Key('installment_$y'))).data, '۷۰۰٬۰۰۰٬۰۰۰ تومان');
    }
  });

  testWidgets('server rate 2.5 billion updates the result without app update', (tester) async {
    final body = modifiedJson((m) => m['full_diyeh_toman'] = 2500000000);
    await pumpApp(tester, client: MockClient((_) async => http.Response.bytes(utf8.encode(body), 200)));
    await pick(tester, 'teeth', 'tooth_front');
    expect(totalText(tester), '۱۲۵٬۰۰۰٬۰۰۰ تومان');
    expect(find.textContaining('به‌روز از سرور'), findsOneWidget);
  });

  testWidgets('offline with cache: uses the last cached rate', (tester) async {
    final cached = modifiedJson((m) {
      m['full_diyeh_toman'] = 2500000000;
      m['updated_at'] = '1405-09-01';
    });
    await pumpApp(tester, cache: MemoryRatesCache(CachedRates(cached, '"x"')));
    await pick(tester, 'teeth', 'tooth_front');
    expect(totalText(tester), '۱۲۵٬۰۰۰٬۰۰۰ تومان');
    expect(find.textContaining('آخرین نرخ ذخیره‌شده'), findsOneWidget);
  });

  testWidgets('help button shows the help text', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('help_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('سهمیه مصرف نمی‌کند'), findsOneWidget);
  });

  testWidgets('dark mode renders', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester);
    expect(Theme.of(tester.element(find.byKey(const Key('add_injury_button')))).brightness, Brightness.dark);
  });

  testWidgets('no layout overflow on a narrow 360px phone', (tester) async {
    await pumpApp(tester);
    tester.view.physicalSize = const Size(1080, 9000); // 360 logical px wide
    await tester.pumpAndSettle();
    await pick(tester, 'teeth', 'tooth_black');
    await pick(tester, 'teeth', 'tooth_crown_partial');
    await pick(tester, 'nafs', 'nafs');
    await pick(tester, 'hand_foot', 'hand_both');
    await tester.tap(find.byKey(const Key('payment_shebh_amd')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('installment_2')), findsOneWidget);
  });
}
