import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/models/cooking_conditions.dart';
import 'package:kinyangdeechao/models/ingredient.dart';
import 'package:kinyangdeechao/models/recipe.dart';
import 'package:kinyangdeechao/models/scan_record.dart';
import 'package:kinyangdeechao/screens/ingredient_result_screen.dart';
import 'package:kinyangdeechao/screens/recipe_detail_screen.dart';
import 'package:kinyangdeechao/services/api_service.dart';

import 'test_helpers.dart';

Recipe _ai(String name, {bool? spicy, int prep = 5, int cook = 10}) => Recipe(
      id: 'ai-$name',
      nameTh: name,
      primaryIngredientId: '',
      ingredients: const [
        RecipeIngredient('ไข่เค็ม', amount: 1, unit: 'ฟอง'),
        RecipeIngredient('ข้าวสวย', ingredientId: 'rice', amount: 1, unit: 'ถ้วย'),
      ],
      steps: const ['หนึ่ง', 'สอง', 'สาม'],
      prepMinutes: prep,
      cookMinutes: cook,
      spicyFlag: spicy,
      isAiGenerated: true,
    );

const _saltedEgg =
    DetectedIngredient(id: 'salted_egg', nameTh: 'ไข่เค็ม', known: false);

Future<Harness> _open(WidgetTester tester, ScanRecord record,
    {String? apiKey = 'test-key'}) async {
  usePhone(tester);
  final h = await Harness.create({}, apiKey);
  await h.history.add(record);
  await tester.pumpWidget(h.wrap(IngredientResultScreen(recordId: record.id)));
  await tester.pumpAndSettle();
  return h;
}

/// แตะขอเมนูจาก AI (ระหว่างรอจะมีแอนิเมชันโหลดวนอยู่ จึงไม่ใช้ pumpAndSettle)
Future<void> _requestAi(WidgetTester tester) async {
  final button = find.text('ขอเมนูจาก AI ตามวัตถุดิบและเงื่อนไขนี้');
  await tester.scrollUntilVisible(button, 200);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('shows confirmed ingredients, curated recipes and an AI button',
      (tester) async {
    final h = await _open(tester, confirmedRecord('r1', const [egg, tomato]));

    expect(find.text('วัตถุดิบที่ยืนยันแล้ว'), findsOneWidget);
    expect(find.text('มะเขือเทศ'), findsOneWidget);
    expect(find.text('ไข่ผัดมะเขือเทศ'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('ขอเมนูจาก AI ตามวัตถุดิบและเงื่อนไขนี้'), 300);
    expect(h.api.suggestCalls, 0, reason: 'ไม่เรียก AI เองเมื่อเปิดหน้า');
  });

  testWidgets('no curated match → AI only when the user asks', (tester) async {
    final h = await _open(tester, confirmedRecord('r1', const [_saltedEgg]));
    expect(h.api.suggestCalls, 0);
    expect(find.textContaining('ยังไม่มีสูตรในแอปที่ใช้วัตถุดิบเหล่านี้'),
        findsOneWidget);

    await _requestAi(tester);
    expect(h.api.suggestCalls, 1);
    expect(h.api.lastSuggestInput, const [_saltedEgg]);
    expect(h.api.lastSuggestKitchen, contains('oil'));

    h.api.suggest.complete([_ai('ข้าวไข่เค็ม')]);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('ข้าวไข่เค็ม'), 200);
    expect(find.text('ขาด ข้าวสวย'), findsOneWidget);
    final cache = h.history.byId('r1')!.ai!;
    expect(cache.recipes.single.nameTh, 'ข้าวไข่เค็ม');
    expect(cache.inputKey, isNotNull);
    expect(h.history.byId('r1')!.traces.last.kind.name, 'suggest');
  });

  testWidgets('saved AI recipes for the same input are reused offline',
      (tester) async {
    final base = confirmedRecord('r1', const [_saltedEgg]);
    final h0 = await Harness.create();
    final key = ApiService.suggestionInputKey(
      owned: base.ingredients,
      kitchen: base.kitchen,
      conditions: base.conditions,
      config: h0.ai.config,
    );
    final h = await _open(
      tester,
      base.copyWith(ai: AiRecipeCache(recipes: [_ai('เมนูเก่า')], inputKey: key)),
    );
    await tester.scrollUntilVisible(find.text('เมนูเก่า'), 200);
    expect(find.textContaining('ผลที่บันทึกไว้'), findsOneWidget);
    expect(find.textContaining('เมื่อเมื่อ'), findsNothing);
    expect(h.api.suggestCalls, 0);
  });

  testWidgets('changing conditions marks saved AI recipes as stale',
      (tester) async {
    final base = confirmedRecord('r1', const [_saltedEgg]);
    final h = await _open(tester,
        base.copyWith(ai: AiRecipeCache(recipes: [_ai('เมนูเก่า')], inputKey: 'other')));
    await tester.scrollUntilVisible(find.textContaining('จึงแสดงเป็นผลเก่า'), 200);
    expect(find.text('เมนูเก่า'), findsOneWidget);
    expect(h.api.suggestCalls, 0);
  });

  testWidgets('conditions filter curated recipes and are sent to AI',
      (tester) async {
    final h = await _open(tester, confirmedRecord('r1', const [pork]));
    // ผัดกะเพรา (เผ็ด) อยู่ในผลก่อนกรอง
    await tester.scrollUntilVisible(find.text('ผัดกะเพราหมูสับ'), 200);
    expect(find.textContaining('เมนูที่ไม่ตรงเงื่อนไข'), findsNothing);
    await tester.scrollUntilVisible(find.text('เงื่อนไขการทำอาหาร'), -300);

    await tester.tap(find.text('เงื่อนไขการทำอาหาร'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ไม่เผ็ด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ไม่เผ็ด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ใช้เงื่อนไขนี้'));
    await tester.pumpAndSettle();

    expect(h.history.byId('r1')!.conditions.spice, SpicePreference.mild);
    expect(h.settings.conditions.spice, SpicePreference.mild);
    // เมนูเผ็ดถูกซ่อนไว้หลังปุ่ม ไม่ได้หายไปเฉย ๆ
    final more = find.textContaining('เมนูที่ไม่ตรงเงื่อนไข');
    await tester.scrollUntilVisible(more, 200);
    expect(find.text('ผัดกะเพราหมูสับ'), findsNothing);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ผัดกะเพราหมูสับ'), 200);
    expect(find.textContaining('เป็นเมนูเผ็ด'), findsWidgets);

    await tester.scrollUntilVisible(
        find.text('ขอเมนูจาก AI ตามวัตถุดิบและเงื่อนไขนี้'), 200);
    await _requestAi(tester);
    expect(h.api.lastSuggestConditions!.spice, SpicePreference.mild);
  });

  testWidgets('a late AI response after conditions change is discarded',
      (tester) async {
    final h = await _open(tester, confirmedRecord('r1', const [_saltedEgg]));
    await _requestAi(tester);
    final firstToken = h.api.lastSuggestToken!;

    // ระหว่างรอ AI มีแอนิเมชันโหลด จึงใช้ pump แทน pumpAndSettle
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pump(const Duration(milliseconds: 500));
    Future<void> frames() async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    await tester.tap(find.text('เงื่อนไขการทำอาหาร'));
    await frames();
    await tester.tap(find.text('ไม่เกิน 15 นาที'));
    await tester.tap(find.text('ใช้เงื่อนไขนี้'));
    await frames();
    expect(firstToken.isCancelled, isTrue);

    h.api.suggest.complete([_ai('ผลของคำขอเก่า')]);
    await tester.pumpAndSettle();
    expect(find.text('ผลของคำขอเก่า'), findsNothing);
    expect(h.history.byId('r1')!.ai, isNull);
  });

  testWidgets('AI failure keeps curated recipes usable with a real message',
      (tester) async {
    final h = await _open(tester, confirmedRecord('r1', const [egg, _saltedEgg]));
    await _requestAi(tester);
    h.api.suggest.completeError(
        const RecognitionException(RecognitionErrorType.rateLimited));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ลองใหม่'), 200);
    expect(
        find.textContaining(
            const RecognitionException(RecognitionErrorType.rateLimited).userMessage),
        findsOneWidget);
    expect(find.textContaining('สูตรในแอปด้านบนยังใช้ได้ตามปกติ'), findsOneWidget);
  });

  testWidgets('without an API key the AI section offers setup instead',
      (tester) async {
    final h = await _open(tester, confirmedRecord('r1', const [_saltedEgg]),
        apiKey: null);
    if (h.ai.hasKey) return; // มี key ติดมากับ build นี้
    await tester.scrollUntilVisible(find.text('ตั้งค่า AI'), 200);
    expect(h.api.suggestCalls, 0);
  });

  testWidgets('opening a recipe shows the explanation with real numbers',
      (tester) async {
    await _open(tester, confirmedRecord('r1', const [egg, tomato]));
    await tester.tap(find.text('ไข่ผัดมะเขือเทศ'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ทำไมแนะนำเมนูนี้'), 200);
    // ไข่ + มะเขือเทศ (+ กระเทียม = ของในครัวไม่ได้เลือก → ต้องเตรียม)
    expect(find.text('มีวัตถุดิบหลัก 2/2 อย่าง'), findsOneWidget);
    expect(find.textContaining('กระเทียม'), findsWidgets);
    expect(find.text('แหล่งสูตร: สูตรในแอป'), findsOneWidget);
  });
}
