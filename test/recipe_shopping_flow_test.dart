import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/data/recipe_repository.dart';
import 'package:kinyangdeechao/models/shopping_item.dart';
import 'package:kinyangdeechao/screens/recipe_detail_screen.dart';

import 'test_helpers.dart';

/// ซื้อของจากหน้าสูตรผ่านปุ่มจริง: ติ๊ก/เอาติ๊ก, เปลี่ยนจำนวนที่, สูตรที่สอง, ของเสริม
/// (จอ 360×640 ไม่ขยาย viewport — เลื่อนไปหาปุ่มเอง)

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

/// แถวส่วนผสมในส่วน "ส่วนผสม" (ชื่ออาจซ้ำกับข้อความสรุปด้านบน จึงเลือกตัวที่อยู่ใน InkWell)
Finder _row(String name) => find.descendant(
      of: find.byType(InkWell),
      matching: find.text(name),
    );

/// ปุ่มเพิ่ม/อัปเดตรายการซื้อของ (ข้อความอธิบายใต้ส่วนผสมก็มีคำว่า "ลงรายการซื้อ" จึงใช้ชนิดปุ่ม)
final _addBtn = find.byType(OutlinedButton);

ShoppingItem _item(Harness h, String id) =>
    h.shopping.items.firstWhere((i) => i.ingredientId == id);

Set<String?> _ids(Harness h) => h.shopping.items.map((i) => i.ingredientId).toSet();

void main() {
  const repo = RecipeRepository();

  testWidgets(
      'un-ticking owned items and kitchen staples makes them buyable; optional never is',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    final match = repo
        .matchRecipes(const [egg], kitchen: {'oil'})
        .firstWhere((m) => m.recipe.id == 'EGG-01');
    await tester.pumpWidget(h.wrap(RecipeDetailScreen(match: match)));
    await tester.pumpAndSettle();

    // เริ่มต้น: ขาดหมูสับ + น้ำปลา (ไข่=มีแล้ว, น้ำมัน=ในครัว, ต้นหอม=ของเสริม)
    await _see(tester, find.text('เพิ่มของที่ยังไม่ได้ติ๊ก (2) ลงรายการซื้อ'));

    // เอาติ๊ก "ไข่ไก่" (มีแล้ว) และ "น้ำมัน" (ในครัว) ออก → ต้องซื้อด้วย
    await _tapSeen(tester, _row('ไข่ไก่'));
    await _tapSeen(tester, _row('น้ำมันพืช'));
    await _see(tester, find.text('เพิ่มของที่ยังไม่ได้ติ๊ก (4) ลงรายการซื้อ'));

    await _tapSeen(tester, find.text('เพิ่มของที่ยังไม่ได้ติ๊ก (4) ลงรายการซื้อ'));
    expect(_ids(h), {'egg', 'pork', 'fish_sauce', 'oil'});
    expect(_ids(h), isNot(contains('spring_onion')),
        reason: 'ของเสริมไม่ถูกซื้อ');
  });

  testWidgets('ticking a missing item removes it from what will be bought',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    final match = repo
        .matchRecipes(const [egg], kitchen: {'oil'})
        .firstWhere((m) => m.recipe.id == 'EGG-01');
    await tester.pumpWidget(h.wrap(RecipeDetailScreen(match: match)));
    await tester.pumpAndSettle();

    await _tapSeen(tester, _row('น้ำปลา')); // บอกว่ามีน้ำปลาแล้ว
    await _tapSeen(tester, find.text('เพิ่มของที่ยังไม่ได้ติ๊ก (1) ลงรายการซื้อ'));
    expect(_ids(h), {'pork'});
  });

  testWidgets('pantry staples can be bought after un-ticking in browse mode',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    final r = RecipeRepository.byId('EGG-01')!;
    await tester
        .pumpWidget(h.wrap(RecipeDetailScreen(match: RecipeMatch.browse(r))));
    await tester.pumpAndSettle();
    // browse: ของจำเป็นทั้ง 4 (ไข่ หมูสับ น้ำปลา น้ำมัน) ยังไม่ติ๊ก, ต้นหอมเป็นของเสริม
    await _tapSeen(tester, find.text('เพิ่มของที่ยังไม่ได้ติ๊ก (4) ลงรายการซื้อ'));
    expect(_ids(h), {'egg', 'pork', 'fish_sauce', 'oil'});
  });

  testWidgets(
      'changing servings 2→3 updates quantities through the button (no double add)',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    final r = RecipeRepository.byId('PORK-02')!; // 2 ที่ · หมู 300 กรัม
    expect(r.servings, 2);
    await tester
        .pumpWidget(h.wrap(RecipeDetailScreen(match: RecipeMatch.browse(r))));
    await tester.pumpAndSettle();

    await _tapSeen(tester, _addBtn);
    expect(_item(h, 'pork').amount, '300 กรัม');
    await _see(tester, find.text('อยู่ในรายการซื้อของแล้ว'));
    // ปริมาณตรงแล้ว → ไม่มีอะไรต้องทำ (ปุ่มปิด)
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'อยู่ในรายการซื้อของแล้ว'))
            .onPressed,
        isNull);

    // เปลี่ยนเป็น 3 ที่ → ปุ่มต้องกดได้และเป็นการอัปเดตปริมาณ
    await _tapSeen(tester, find.byTooltip('เพิ่มจำนวนที่'));
    final update = _addBtn;
    await _see(tester, update);
    expect(find.textContaining('อัปเดตปริมาณในรายการซื้อของ'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(update).onPressed, isNotNull);
    await tester.tap(update);
    await tester.pumpAndSettle();

    expect(_item(h, 'pork').amount, '450 กรัม', reason: '300×3/2 ไม่ใช่ 300+450');
    expect(h.shopping.items.length, r.ingredients.length);

    // กดซ้ำที่ 3 ที่เดิมไม่บวกซ้ำ
    await _see(tester, find.text('อยู่ในรายการซื้อของแล้ว'));
    expect(_item(h, 'pork').amount, '450 กรัม');
    expect(_item(h, 'pork').recipes, [r.nameTh]);
  });

  testWidgets('a second recipe sharing an ingredient adds its own contribution',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    final first = RecipeRepository.byId('EGG-01')!; // หมูสับ 50 กรัม (1 ที่)
    final second = RecipeRepository.byId('PORK-01')!; // หมูสับ 150 กรัม (1 ที่)

    await tester.pumpWidget(
        h.wrap(RecipeDetailScreen(match: RecipeMatch.browse(first))));
    await tester.pumpAndSettle();
    await _tapSeen(tester, _addBtn);
    expect(_item(h, 'pork').amount, '50 กรัม');

    // เปิดสูตรที่สอง: หมูสับอยู่ในรายการแล้ว แต่ปุ่มต้องยังเพิ่มส่วนของสูตรนี้ได้
    await tester.pumpWidget(
        h.wrap(RecipeDetailScreen(match: RecipeMatch.browse(second))));
    await tester.pumpAndSettle();
    final add = _addBtn;
    await _see(tester, add);
    expect(tester.widget<OutlinedButton>(add).onPressed, isNotNull,
        reason: 'ห้ามปิดปุ่มเพียงเพราะมี key หมูสับอยู่ในรายการ');
    await tester.tap(add);
    await tester.pumpAndSettle();

    final pork = _item(h, 'pork');
    expect(pork.amount, '200 กรัม');
    expect(pork.recipes, [first.nameTh, second.nameTh]);

    // กดสูตรที่สองซ้ำ → ไม่บวกซ้ำ
    await _see(tester, find.text('อยู่ในรายการซื้อของแล้ว'));
    expect(_item(h, 'pork').amount, '200 กรัม');
  });

  testWidgets('a failed write adds nothing and the button can be retried',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    final r = RecipeRepository.byId('EGG-01')!;
    await tester
        .pumpWidget(h.wrap(RecipeDetailScreen(match: RecipeMatch.browse(r))));
    await tester.pumpAndSettle();
    h.failWrites();
    await _tapSeen(tester, _addBtn);
    expect(h.shopping.items, isEmpty);
    expect(find.textContaining('ไม่สำเร็จ'), findsOneWidget);
    expect(find.text('อยู่ในรายการซื้อของแล้ว'), findsNothing);
    expect(_addBtn, findsOneWidget);
  });
}
