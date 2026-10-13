import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/data/recipe_repository.dart';
import 'package:kinyangdeechao/models/ingredient.dart';
import 'package:kinyangdeechao/models/scan_record.dart';
import 'package:kinyangdeechao/screens/cooking_mode_screen.dart';
import 'package:kinyangdeechao/screens/favorites/favorites_screen.dart';
import 'package:kinyangdeechao/screens/history/history_screen.dart';
import 'package:kinyangdeechao/screens/ingredient_picker_sheet.dart';
import 'package:kinyangdeechao/screens/ingredient_result_screen.dart';
import 'package:kinyangdeechao/screens/onboarding_screen.dart';
import 'package:kinyangdeechao/screens/recipe_detail_screen.dart';
import 'package:kinyangdeechao/screens/review/ingredient_review_screen.dart';
import 'package:kinyangdeechao/screens/summary/analysis_summary_screen.dart';
import 'package:kinyangdeechao/models/cooking_conditions.dart';
import 'package:kinyangdeechao/widgets/conditions_sheet.dart';
import 'package:kinyangdeechao/screens/search/search_screen.dart';
import 'package:kinyangdeechao/screens/settings/ai_settings_screen.dart';
import 'package:kinyangdeechao/screens/settings/settings_screen.dart';
import 'package:kinyangdeechao/screens/shell/app_shell.dart';
import 'package:kinyangdeechao/screens/shopping/shopping_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'test_helpers.dart';

/// จอเล็ก (360x640) + ขยายตัวอักษร 1.3 เท่า (ตั้งค่าการเข้าถึงที่พบบ่อย)
/// ใช้ฟอนต์ทดสอบที่กว้างกว่า Kanit จริง จึงเป็นเกณฑ์ที่เข้มกว่าเครื่องจริง
Future<void> _pump(
  WidgetTester tester,
  Harness h,
  Widget screen, {
  double scale = 1.3,
  ThemeMode mode = ThemeMode.light,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 640),
        textScaler: TextScaler.linear(scale),
      ),
      child: h.wrap(screen, mode: mode),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

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

  Future<Harness> seeded() async {
    final h = await Harness.create({'settings.onboardingDone': true}, null);
    await h.history.add(confirmedRecord('a', const [
      egg,
      DetectedIngredient(id: 'x', nameTh: 'กระเทียมโทนสดใหม่จากสวน', known: false),
    ]));
    await h.history.add(confirmedRecord('r', const [egg, tomato, pork]));
    await h.history.add(confirmedRecord('none', const [
      DetectedIngredient(id: 'y', nameTh: 'ไข่เค็ม', known: false),
    ]));
    await h.history.add(ScanRecord(
      id: 'legacy',
      createdAt: DateTime.now(),
      imageFile: 'legacy.jpg',
      status: ScanStatus.legacy,
      detected: const [egg],
      ingredients: const [egg],
    ));
    await h.history.saveDraft(ScanRecord(
      id: 'draft',
      createdAt: DateTime.now(),
      imageFile: 'draft.jpg',
      status: ScanStatus.draft,
      detected: [egg.withSource(IngredientSource.ai)],
      aiReportedCount: 15,
      ingredients: [
        egg.withSource(IngredientSource.ai),
        const DetectedIngredient(
            id: 'z', nameTh: 'ผักกาดดองเปรี้ยวเผ็ดยี่ห้อยาวมาก', known: false,
            source: IngredientSource.user),
      ],
    ));
    await h.favorites.toggle(RecipeRepository.byId('CARROT-03')!);
    await h.shopping.addFromRecipe(
        RecipeRepository.byId('CHICKEN-04')!, RecipeRepository.byId('CHICKEN-04')!.ingredients);
    return h;
  }

  final longest = RecipeRepository.recipes
      .reduce((a, b) => a.ingredients.length >= b.ingredients.length ? a : b);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode.name;

    testWidgets('no overflow on any screen ($tag)', (tester) async {
      final h = await seeded();
      final screens = <String, Widget>{
        'shell': const AppShell(),
        'history': HistoryScreen(onStartScan: () {}),
        'favorites': const FavoritesScreen(),
        'shopping': const ShoppingScreen(),
        'settings': const SettingsScreen(),
        'ai settings': const AiSettingsScreen(),
        'search': const SearchScreen(),
        'onboarding': OnboardingScreen(onDone: () {}),
        'review draft': const IngredientReviewScreen(recordId: 'draft'),
        'review legacy': const IngredientReviewScreen(recordId: 'legacy'),
        'result': const IngredientResultScreen(recordId: 'r'),
        'result no match': const IngredientResultScreen(recordId: 'none'),
        'result legacy': const IngredientResultScreen(recordId: 'legacy'),
        'summary': const AnalysisSummaryScreen(recordId: 'r'),
        'conditions': const Scaffold(
            body: SafeArea(child: ConditionsForm(initial: CookingConditions.standard))),
        'detail': RecipeDetailScreen(
          match: const RecipeRepository().matchRecipes(const [egg, tomato]).first,
        ),
        'detail longest': RecipeDetailScreen(match: RecipeMatch.browse(longest)),
        'cooking': CookingModeScreen(recipe: longest, servings: 4),
        'picker': const Material(
          child: IngredientPicker(
            initial: [egg, tomato],
            title: 'เลือกวัตถุดิบที่มี',
            confirmLabel: 'ดูเมนูที่ทำได้',
          ),
        ),
      };

      final failing = <String>[];
      for (final e in screens.entries) {
        await _pump(tester, h, e.value, mode: mode);
        final ex = tester.takeException();
        if (ex != null) {
          failing.add('${e.key}: ${ex.toString().split('\n').first}');
        }
      }
      expect(failing, isEmpty);
    });
  }

  testWidgets('shell tabs survive large text on a small phone', (tester) async {
    final h = await seeded();
    await _pump(tester, h, const AppShell(), scale: 1.5);
    final failing = <String>[];
    final first = tester.takeException();
    if (first != null) failing.add('initial: $first');
    for (final tab in ['ประวัติ', 'เมนูโปรด', 'ซื้อของ', 'สแกน']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 400));
      final ex = tester.takeException();
      if (ex != null) {
        failing.add('$tab: ${ex.toString().split('\n').first}');
      }
    }
    expect(failing, isEmpty);
  });
}
