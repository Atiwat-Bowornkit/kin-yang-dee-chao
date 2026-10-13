import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/data/recipe_repository.dart';
import 'package:kinyangdeechao/models/ingredient.dart';
import 'package:kinyangdeechao/models/scan_record.dart';
import 'package:kinyangdeechao/screens/history/history_screen.dart';
import 'package:kinyangdeechao/screens/ingredient_result_screen.dart';
import 'package:kinyangdeechao/screens/review/ingredient_review_screen.dart';
import 'package:kinyangdeechao/screens/settings/settings_screen.dart';
import 'package:kinyangdeechao/screens/shopping/shopping_screen.dart';
import 'package:kinyangdeechao/widgets/favorite_button.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'test_helpers.dart';

/// ข้อความต้องไม่บอกว่าสำเร็จเมื่อเขียนลงเครื่องไม่ได้ (ดิสก์เต็ม: ทุกการเขียนคืน false)
ScanRecord _rec(String id) => ScanRecord(
      id: id,
      createdAt: DateTime.now(),
      imageFile: '$id.jpg',
      ingredients: const [egg],
    );

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'kinyangdeechao',
      packageName: 'app.kinyangdeechao',
      version: '1.2.0',
      buildNumber: '3',
      buildSignature: '',
    );
  });

  group('FavoriteButton', () {
    Widget host(Harness h) => h.wrap(Scaffold(
          body: Center(
            child: FavoriteButton(recipe: RecipeRepository.byId('EGG-01')!),
          ),
        ));

    testWidgets('success says saved', (tester) async {
      final h = await Harness.create();
      await tester.pumpWidget(host(h));
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('บันทึกเป็นเมนูโปรดแล้ว'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('write failure never claims it was saved', (tester) async {
      final h = await Harness.create();
      h.failWrites();
      await tester.pumpWidget(host(h));
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('บันทึกเป็นเมนูโปรดแล้ว'), findsNothing);
      expect(find.textContaining('ยังบันทึกเมนูโปรดลงเครื่องไม่สำเร็จ'),
          findsOneWidget);
      // สถานะใหม่ (หัวใจเต็ม) แยกจากผลการบันทึก
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('failure when removing says it may come back', (tester) async {
      final h = await Harness.create();
      await tester.pumpWidget(host(h));
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      h.failWrites();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('เอาออกจากเมนูโปรดแล้ว'), findsNothing);
      expect(find.textContaining('อาจกลับมาเมื่อเปิดแอปใหม่'), findsOneWidget);
    });
  });

  group('ShoppingScreen', () {
    testWidgets('typed item: write failure is not the duplicate message',
        (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await h.shopping.addName('ไข่ไก่');
      await tester.pumpWidget(h.wrap(const ShoppingScreen()));
      await tester.pumpAndSettle();

      h.failWrites();
      await tester.enterText(find.byType(TextField), 'หมู');
      await tapVisible(tester, find.byTooltip('เพิ่ม'));
      expect(find.textContaining('ยังบันทึกลงเครื่องไม่ได้'), findsOneWidget);
      expect(find.textContaining('อยู่ในรายการแล้ว'), findsNothing);

      // ซ้ำจริง → ข้อความซ้ำ (ไม่ใช่ข้อความเขียนล้มเหลว)
      await tester.enterText(find.byType(TextField), 'ไข่');
      await tapVisible(tester, find.byTooltip('เพิ่ม'));
      expect(find.text('"ไข่" อยู่ในรายการแล้ว'), findsOneWidget);
    });

    testWidgets('toggle failure is reported', (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await h.shopping.addName('ไข่ไก่');
      await tester.pumpWidget(h.wrap(const ShoppingScreen()));
      await tester.pumpAndSettle();
      h.failWrites();
      await tapVisible(tester, find.text('ไข่ไก่'));
      expect(find.textContaining('ยังบันทึกการติ๊กลงเครื่องไม่สำเร็จ'),
          findsOneWidget);
    });

    testWidgets('swipe delete failure: item stays, no false success',
        (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await h.shopping.addName('ไข่ไก่');
      await tester.pumpWidget(h.wrap(const ShoppingScreen()));
      await tester.pumpAndSettle();
      h.failWrites();
      await tester.drag(find.text('ไข่ไก่'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(h.shopping.items, hasLength(1));
      expect(find.textContaining('ลบ "ไข่ไก่" ไม่สำเร็จ'), findsOneWidget);
      expect(find.text('ลบ "ไข่ไก่" แล้ว'), findsNothing);
    });

    testWidgets('clear-all failure keeps the items and says so', (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await h.shopping.addName('ไข่ไก่');
      await tester.pumpWidget(h.wrap(const ShoppingScreen()));
      await tester.pumpAndSettle();
      h.failWrites();
      await tapVisible(tester, find.byTooltip('ตัวเลือก'));
      await tapVisible(tester, find.text('ล้างทั้งหมด').first);
      await tapVisible(tester, find.text('ล้างทั้งหมด').last);
      expect(h.shopping.items, hasLength(1));
      expect(find.text('ล้างรายการซื้อของแล้ว'), findsNothing);
      expect(find.textContaining('ล้างรายการซื้อของไม่สำเร็จ'), findsOneWidget);
    });

    testWidgets('clear-checked failure keeps the items', (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await h.shopping.addName('ไข่ไก่');
      await h.shopping.toggle(h.shopping.items.single.id);
      await tester.pumpWidget(h.wrap(const ShoppingScreen()));
      await tester.pumpAndSettle();
      h.failWrites();
      await tapVisible(tester, find.byTooltip('ตัวเลือก'));
      await tapVisible(tester, find.text('ลบที่ซื้อแล้ว'));
      expect(h.shopping.items, hasLength(1));
      expect(find.textContaining('ลบที่ซื้อแล้วไม่สำเร็จ'), findsOneWidget);
    });
  });

  group('HistoryScreen', () {
    testWidgets('delete failure: record stays and the image is untouched',
        (tester) async {
      final h = await Harness.create();
      await h.history.add(_rec('a'));
      h.images.files.add('a.jpg');
      await tester.pumpWidget(h.wrap(HistoryScreen(onStartScan: () {})));
      await tester.pumpAndSettle();
      h.failWrites();
      await tapVisible(tester, find.byTooltip('ลบรายการ').first);
      expect(h.history.records, hasLength(1));
      expect(find.textContaining('ลบไม่สำเร็จ'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(h.images.deleted, isEmpty);
    });

    testWidgets('clear failure is reported, data and images stay', (tester) async {
      final h = await Harness.create();
      await h.history.add(_rec('a'));
      await tester.pumpWidget(h.wrap(HistoryScreen(onStartScan: () {})));
      await tester.pumpAndSettle();
      h.failWrites();
      await tapVisible(tester, find.byTooltip('ตัวเลือก'));
      await tapVisible(tester, find.text('ล้างประวัติทั้งหมด').last);
      await tapVisible(tester, find.text('ล้างทั้งหมด'));
      expect(h.history.records, hasLength(1));
      expect(find.text('ล้างประวัติแล้ว'), findsNothing);
      expect(find.textContaining('ล้างประวัติไม่สำเร็จ'), findsOneWidget);
      expect(h.images.deleted, isEmpty);
    });
  });

  group('SettingsScreen', () {
    testWidgets('clear failure does not say it was cleared', (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await h.history.add(_rec('a'));
      await tester.pumpWidget(h.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      h.failWrites();
      await tapVisible(tester, find.text('ล้างประวัติการสแกน'));
      await tapVisible(tester, find.text('ล้างประวัติ'));
      expect(h.history.records, hasLength(1));
      expect(find.text('ล้างประวัติแล้ว'), findsNothing);
      expect(find.textContaining('ล้างไม่สำเร็จ'), findsOneWidget);
    });
  });

  group('IngredientReviewScreen', () {
    ScanRecord draft() => ScanRecord(
          id: 'd1',
          createdAt: DateTime.now(),
          imageFile: 'd1.jpg',
          status: ScanStatus.draft,
          detected: [egg.withSource(IngredientSource.ai)],
          ingredients: [egg.withSource(IngredientSource.ai)],
          kitchen: const {'oil'},
        );

    testWidgets('confirm write failure: stays on the page, draft intact',
        (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await h.history.saveDraft(draft());
      await tester.pumpWidget(h.wrap(const IngredientReviewScreen(recordId: 'd1')));
      await tester.pumpAndSettle();

      h.failWrites();
      await tester.tap(find.text('ยืนยันวัตถุดิบและหาเมนู (1)'));
      await tester.pumpAndSettle();

      expect(find.byType(IngredientResultScreen), findsNothing);
      expect(find.byType(IngredientReviewScreen), findsOneWidget);
      expect(find.textContaining('ยืนยันไม่สำเร็จ'), findsOneWidget);
      expect(h.history.draft?.id, 'd1');
      expect(h.history.records, isEmpty);
      expect(h.images.deleted, isEmpty);
    });

    testWidgets('editing while the draft cannot be saved warns once',
        (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await h.history.saveDraft(draft());
      await tester.pumpWidget(h.wrap(const IngredientReviewScreen(recordId: 'd1')));
      await tester.pumpAndSettle();

      h.failWrites();
      await tapVisible(tester, find.byTooltip('ลบ ไข่ไก่'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ยังบันทึกร่างลงเครื่องไม่สำเร็จ'),
          findsOneWidget);
    });
  });
}
