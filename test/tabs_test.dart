import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/data/recipe_repository.dart';
import 'package:kinyangdeechao/models/scan_record.dart';
import 'package:kinyangdeechao/screens/favorites/favorites_screen.dart';
import 'package:kinyangdeechao/screens/history/history_screen.dart';
import 'package:kinyangdeechao/screens/review/ingredient_review_screen.dart';
import 'package:kinyangdeechao/screens/scan/scan_screen.dart';
import 'package:kinyangdeechao/screens/ingredient_result_screen.dart';
import 'package:kinyangdeechao/screens/search/search_screen.dart';
import 'package:kinyangdeechao/screens/settings/ai_settings_screen.dart';
import 'package:kinyangdeechao/screens/settings/settings_screen.dart';
import 'package:kinyangdeechao/screens/shopping/shopping_screen.dart';
import 'package:kinyangdeechao/services/api_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'test_helpers.dart';

ScanRecord _rec(String id, int minutesAgo) => ScanRecord(
      id: id,
      createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
      imageFile: '$id.jpg',
      ingredients: id == 'b' ? const [tomato] : const [egg],
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

  group('HistoryScreen', () {
    testWidgets('lists records and opens a result', (tester) async {
      final h = await Harness.create();
      await h.history.add(_rec('a', 30));
      await h.history.add(_rec('b', 5));
      await tester.pumpWidget(h.wrap(HistoryScreen(onStartScan: () {})));
      await tester.pumpAndSettle();

      expect(find.text('มะเขือเทศ'), findsOneWidget);
      expect(find.textContaining('5 นาทีที่แล้ว'), findsOneWidget);
      await tapVisible(tester, find.text('มะเขือเทศ'));
      expect(find.byType(IngredientResultScreen), findsOneWidget);
    });

    testWidgets('delete then undo restores the record without deleting files',
        (tester) async {
      final h = await Harness.create();
      await h.history.add(_rec('a', 30));
      await h.history.add(_rec('b', 5));
      await tester.pumpWidget(h.wrap(HistoryScreen(onStartScan: () {})));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byTooltip('ลบรายการ').first);
      expect(h.history.records.map((r) => r.id), ['a']);
      await tapVisible(tester, find.text('เลิกทำ'));
      expect(h.history.records.map((r) => r.id), ['b', 'a']);
      expect(h.images.deleted, isEmpty);
    });

    testWidgets('two deletes in a row only delete the first image',
        (tester) async {
      final h = await Harness.create();
      await h.history.add(_rec('a', 30));
      await h.history.add(_rec('b', 5));
      await tester.pumpWidget(h.wrap(HistoryScreen(onStartScan: () {})));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('ลบรายการ').first); // b
      await tester.pump();
      await tester.tap(find.byTooltip('ลบรายการ').first); // a
      await tester.pumpAndSettle();
      expect(h.images.deleted, ['b.jpg']);
      await tapVisible(tester, find.text('เลิกทำ'));
      expect(h.history.records.map((r) => r.id), ['a']);
      expect(h.images.deleted, ['b.jpg']);
    });

    testWidgets('clear all asks for confirmation and shows a toast',
        (tester) async {
      final h = await Harness.create();
      await h.history.add(_rec('a', 1));
      await tester.pumpWidget(h.wrap(HistoryScreen(onStartScan: () {})));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('ตัวเลือก'));
      await tapVisible(tester, find.text('ล้างประวัติทั้งหมด').last);
      await tapVisible(tester, find.text('ล้างทั้งหมด'));
      expect(h.history.isEmpty, isTrue);
      expect(find.text('ล้างประวัติแล้ว'), findsOneWidget);
    });

    testWidgets('empty state button starts scanning', (tester) async {
      final h = await Harness.create();
      var started = false;
      await tester.pumpWidget(h.wrap(HistoryScreen(onStartScan: () => started = true)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เริ่มสแกน'));
      expect(started, isTrue);
    });
  });

  group('FavoritesScreen', () {
    testWidgets('lists favorites and the empty state links to all recipes',
        (tester) async {
      final h = await Harness.create();
      await tester.pumpWidget(h.wrap(const FavoritesScreen()));
      await tester.pumpAndSettle();
      expect(find.text('ยังไม่มีเมนูโปรด'), findsOneWidget);

      await h.favorites.toggle(RecipeRepository.byId('EGG-01')!);
      await tester.pumpAndSettle();
      expect(find.text('ไข่เจียวหมูสับ'), findsOneWidget);
    });
  });

  group('ScanScreen', () {
    // regression: แอปถูกปิดระหว่างตรวจ → เปิดใหม่แล้วหน้าสแกนว่างทั้งหน้า (ปุ่มกว้างไม่จำกัดใน Row)
    testWidgets('a pending draft shows a banner to resume or discard', (tester) async {
      usePhone(tester);
      final h = await Harness.create({'settings.onboardingDone': true});
      await h.history.saveDraft(ScanRecord(
        id: 'd',
        createdAt: DateTime.now(),
        imageFile: 'd.jpg',
        status: ScanStatus.draft,
        detected: const [egg],
        ingredients: const [egg],
      ));
      await tester.pumpWidget(h.wrap(ScanScreen(onOpenTab: (_) {})));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('มีผลสแกนที่ยังไม่ยืนยัน'), findsOneWidget);
      expect(find.text('ถ่ายภาพวัตถุดิบ'), findsOneWidget);

      await tapVisible(tester, find.text('ตรวจต่อ'));
      expect(find.byType(IngredientReviewScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(IngredientReviewScreen))).pop();
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('ทิ้ง'));
      await tapVisible(tester, find.text('ทิ้ง').last);
      expect(h.history.draft, isNull);
      expect(h.images.deleted, ['d.jpg']);
    });
  });

  group('SearchScreen', () {
    testWidgets('shows every recipe, searches and filters', (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await tester.pumpWidget(h.wrap(const SearchScreen()));
      await tester.pumpAndSettle();
      expect(find.text('ทั้งหมด ${RecipeRepository.recipes.length} เมนู'),
          findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ต้มยำ');
      await tester.pumpAndSettle();
      expect(find.text('ต้มยำกุ้ง'), findsOneWidget);

      expect(find.text('ก๋วยเตี๋ยวต้มยำ'), findsOneWidget);
      await tapVisible(tester, find.text('ทำง่าย'));
      // ต้มยำกุ้งระดับปานกลาง ถูกกรองออก เหลือก๋วยเตี๋ยวต้มยำ (ง่าย)
      expect(find.text('ต้มยำกุ้ง'), findsNothing);
      expect(find.text('ก๋วยเตี๋ยวต้มยำ'), findsOneWidget);
      await tapVisible(tester, find.text('ล้างตัวกรอง'));
      expect(find.text('ต้มยำกุ้ง'), findsOneWidget);
    });
  });

  group('ShoppingScreen', () {
    testWidgets('add, toggle and clear checked', (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await tester.pumpWidget(h.wrap(const ShoppingScreen()));
      await tester.pumpAndSettle();
      expect(find.text('ยังไม่มีรายการซื้อของ'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ไข่');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('ไข่ไก่'), findsOneWidget);
      expect(find.text('เหลืออีก 1 รายการ'), findsOneWidget);

      await tapVisible(tester, find.text('ไข่ไก่'));
      expect(find.text('ซื้อครบแล้ว 🎉'), findsOneWidget);

      await tapVisible(tester, find.byTooltip('ตัวเลือก'));
      await tapVisible(tester, find.text('ลบที่ซื้อแล้ว'));
      expect(h.shopping.isEmpty, isTrue);
    });

    testWidgets('duplicates are rejected with a message', (tester) async {
      final h = await Harness.create();
      await h.shopping.addName('ไข่ไก่');
      await tester.pumpWidget(h.wrap(const ShoppingScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ไข่');
      await tapVisible(tester, find.byTooltip('เพิ่ม'));
      expect(find.text('"ไข่" อยู่ในรายการแล้ว'), findsOneWidget);
      expect(h.shopping.items.length, 1);
    });
  });

  group('SettingsScreen', () {
    testWidgets('clearing history requires confirmation', (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await h.history.add(_rec('a', 1));
      await tester.pumpWidget(h.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('ล้างประวัติการสแกน'));
      await tapVisible(tester, find.text('ยกเลิก'));
      expect(h.history.isEmpty, isFalse);

      await tapVisible(tester, find.text('ล้างประวัติการสแกน'));
      await tapVisible(tester, find.text('ล้างประวัติ'));
      expect(h.history.isEmpty, isTrue);
      expect(find.text('ล้างประวัติแล้ว'), findsOneWidget);
    });

    testWidgets('theme switch and version are shown', (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await tester.pumpWidget(h.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('มืด'));
      expect(h.settings.themeMode, ThemeMode.dark);
      await seeVisible(tester, find.text('เวอร์ชัน 1.2.0 (3)'));
    });

    testWidgets('replay onboarding opens it as a page and returns',
        (tester) async {
      usePhone(tester);
      final h = await Harness.create({'settings.onboardingDone': true});
      await tester.pumpWidget(h.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('ดูวิธีใช้งานอีกครั้ง'));
      expect(find.text('ถ่ายภาพวัตถุดิบ'), findsOneWidget);
      await tapVisible(tester, find.text('ข้าม'));
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(h.settings.onboardingDone, isTrue);
    });
  });

  group('AiSettingsScreen', () {
    testWidgets('saves a key into secure storage', (tester) async {
      final h = await Harness.create({}, null);
      await tester.pumpWidget(h.wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ));
      await tapVisible(tester, find.text('open'));

      await tester.enterText(find.byType(TextField).first, 'sk-123');
      await tapVisible(tester, find.text('บันทึก'));
      expect(await h.secrets.read('ai.apiKey'), 'sk-123');
      expect(find.byType(AiSettingsScreen), findsNothing);
    });

    testWidgets('test connection reports success and failure', (tester) async {
      usePhone(tester);
      final h = await Harness.create();
      await tester.pumpWidget(h.wrap(const AiSettingsScreen()));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('ทดสอบการเชื่อมต่อ'));
      await seeVisible(tester, find.textContaining('เชื่อมต่อสำเร็จ พร้อมใช้งาน'));
      expect(h.ai.lastTest?.ok, isTrue, reason: 'บันทึกผลทดสอบล่าสุด');

      h.api.testError = const RecognitionException(RecognitionErrorType.unauthorized);
      await tapVisible(tester, find.text('ทดสอบการเชื่อมต่อ'));
      expect(
        find.text(const RecognitionException(RecognitionErrorType.unauthorized).userMessage),
        findsOneWidget,
      );
    });
  });
}
