import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/data/recipe_repository.dart';
import 'package:kinyangdeechao/screens/cooking_mode_screen.dart';
import 'package:kinyangdeechao/screens/recipe_detail_screen.dart';

import 'test_helpers.dart';

/// เลื่อนหน้าสูตรจนเห็น [f] (จอ 360x640 ไม่ขยาย viewport)
Future<void> _see(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> _tapSeen(WidgetTester tester, Finder f) async {
  await _see(tester, f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  const repo = RecipeRepository();

  testWidgets('browse mode shows info, ingredients with amounts and steps',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    final r = RecipeRepository.byId('EGG-01')!;
    await tester.pumpWidget(h.wrap(RecipeDetailScreen(match: RecipeMatch.browse(r))));
    await tester.pumpAndSettle();

    expect(find.text(r.nameTh), findsWidgets);
    expect(find.text('สูตรในแอป'), findsOneWidget);
    await _see(tester, find.text('1 ที่'));
    await _see(tester, find.text('2 ฟอง'));
    await _see(tester, find.text('เครื่องปรุงพื้นฐาน'));
    expect(find.textContaining('มีวัตถุดิบหลักครบแล้ว'), findsNothing);
  });

  testWidgets('servings stepper scales amounts', (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    final r = RecipeRepository.byId('EGG-01')!;
    await tester.pumpWidget(h.wrap(RecipeDetailScreen(match: RecipeMatch.browse(r))));
    await tester.pumpAndSettle();

    await _tapSeen(tester, find.byTooltip('เพิ่มจำนวนที่'));
    expect(find.text('2 ที่'), findsOneWidget);
    await _see(tester, find.text('4 ฟอง'));
    await _see(tester, find.text('100 กรัม'));
  });

  testWidgets('from a scan: owned items are marked and missing ones go to shopping',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    // ผู้ใช้เลือกว่ามีน้ำมันในครัว แต่ไม่ได้เลือกน้ำปลา
    final match = repo
        .matchRecipes(const [egg], kitchen: {'oil'})
        .firstWhere((m) => m.recipe.id == 'EGG-01');
    await tester.pumpWidget(h.wrap(RecipeDetailScreen(match: match)));
    await tester.pumpAndSettle();

    await _see(tester, find.text('ขาดอีก 1 อย่าง'));
    await _see(tester, find.text('มีแล้ว'));
    await _see(tester, find.text('มีในครัว'));
    await _see(tester, find.text('ต้องเตรียม'));

    await _tapSeen(tester, find.text('เพิ่มของที่ยังไม่ได้ติ๊ก (2) ลงรายการซื้อ'));

    // หมูสับ (ขาด) + น้ำปลา (ไม่ได้เลือกว่ามีในครัว)
    // ไม่รวม: ไข่ (มีแล้ว), น้ำมัน (มีในครัว), ต้นหอม (ของเสริม)
    expect(h.shopping.items.map((i) => i.ingredientId).toSet(),
        {'pork', 'fish_sauce'});
    await _see(tester, find.text('อยู่ในรายการซื้อของแล้ว'));
  });

  testWidgets('favorite heart toggles', (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    final r = RecipeRepository.byId('EGG-02')!;
    await tester.pumpWidget(h.wrap(RecipeDetailScreen(match: RecipeMatch.browse(r))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('บันทึกเป็นเมนูโปรด'));
    await tester.pumpAndSettle();
    expect(h.favorites.isFavorite(r), isTrue);
  });

  testWidgets('cooking mode walks through every step to the done page',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    final r = RecipeRepository.byId('TOMATO-02')!;
    await tester.pumpWidget(h.wrap(RecipeDetailScreen(match: RecipeMatch.browse(r))));
    await tester.pumpAndSettle();

    await _tapSeen(tester, find.text('เริ่มโหมดทำอาหาร'));
    expect(find.byType(CookingModeScreen), findsOneWidget);
    expect(find.text('ขั้นตอนที่ 1 จาก ${r.steps.length}'), findsOneWidget);

    for (var i = 1; i < r.steps.length; i++) {
      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('เสร็จแล้ว'));
    await tester.pumpAndSettle();
    expect(find.text('เสร็จแล้ว! น่ากินมาก'), findsOneWidget);

    await tester.tap(find.text('กลับไปที่สูตร'));
    await tester.pumpAndSettle();
    expect(find.byType(CookingModeScreen), findsNothing);
  });

  testWidgets('share sheet previews the card with both share options',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    final r = RecipeRepository.byId('EGG-01')!;
    await tester.pumpWidget(h.wrap(RecipeDetailScreen(match: RecipeMatch.browse(r))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('แชร์สูตร'));
    await tester.pumpAndSettle();
    expect(find.text('แชร์ข้อความ'), findsOneWidget);
    expect(find.text('แชร์รูปการ์ด'), findsOneWidget);
  });
}
