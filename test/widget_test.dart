import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/app.dart';
import 'package:kinyangdeechao/screens/scan/scan_screen.dart';
import 'package:kinyangdeechao/screens/shell/app_shell.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('first launch shows onboarding, skip goes to the shell',
      (tester) async {
    final h = await Harness.create();
    await tester.pumpWidget(KinYangDeeChaoApp(data: h.data));
    await tester.pumpAndSettle();

    expect(find.text('ถ่ายภาพวัตถุดิบ'), findsOneWidget);
    await tester.tap(find.text('ข้าม'));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(h.settings.onboardingDone, isTrue);
  });

  testWidgets('onboarding asks for an API key when none is set and saves it',
      (tester) async {
    final h = await Harness.create({}, null);
    await tester.pumpWidget(KinYangDeeChaoApp(data: h.data));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();
    }
    expect(find.text('เชื่อมต่อ AI'), findsOneWidget);
    expect(find.text('ข้ามไปก่อน เริ่มใช้งาน'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'my-key');
    await tester.pump();
    await tester.tap(find.text('เริ่มใช้งาน'));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(h.ai.config.apiKey, 'my-key');
  });

  testWidgets('onboarding is skipped once done', (tester) async {
    final h = await Harness.create({'settings.onboardingDone': true});
    await tester.pumpWidget(KinYangDeeChaoApp(data: h.data));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);
  });

  testWidgets('four tabs switch and system back returns to scan first',
      (tester) async {
    final h = await Harness.create({'settings.onboardingDone': true});
    await tester.pumpWidget(KinYangDeeChaoApp(data: h.data));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ประวัติ').last);
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีประวัติ'), findsOneWidget);

    await tester.tap(find.text('เมนูโปรด').last);
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีเมนูโปรด'), findsOneWidget);

    await tester.tap(find.text('ซื้อของ').last);
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีรายการซื้อของ'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(shellTab.value, ShellTab.scan);
  });

  testWidgets('shopping tab shows a badge with items left to buy',
      (tester) async {
    final h = await Harness.create({'settings.onboardingDone': true});
    await h.shopping.addName('ไข่');
    await h.shopping.addName('หมู');
    await tester.pumpWidget(KinYangDeeChaoApp(data: h.data));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('scan screen shows the AI setup banner without a key',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create({'settings.onboardingDone': true}, null);
    await tester.pumpWidget(KinYangDeeChaoApp(data: h.data));
    await tester.pumpAndSettle();
    final hasBuiltIn = h.ai.hasKey;
    expect(find.text('ตั้งค่า AI ก่อนสแกน'), hasBuiltIn ? findsNothing : findsOneWidget);
    await seeVisible(tester, find.text('เมนูแนะนำวันนี้'));
  });
}
