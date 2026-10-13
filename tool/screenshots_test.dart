// เครื่องมือตรวจ UI: เรนเดอร์หน้าจอจริง (ฟอนต์ Kanit + ไอคอน Material + emoji) เป็น PNG ขนาดมือถือ
// รัน: flutter test tool/screenshots_test.dart --dart-define=SHOT_DIR=build/shots
// ไม่อยู่ใน test/ จึงไม่ถูกรวมกับ `flutter test` ปกติ
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/core/app_scope.dart';
import 'package:kinyangdeechao/data/recipe_repository.dart';
import 'package:kinyangdeechao/models/ingredient.dart';
import 'package:kinyangdeechao/models/recipe.dart';
import 'package:kinyangdeechao/models/scan_record.dart';
import 'package:kinyangdeechao/screens/cooking_mode_screen.dart';
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
import 'package:kinyangdeechao/theme/app_theme.dart';
import 'package:kinyangdeechao/widgets/recipe_share_card.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../test/test_helpers.dart';

const _outDir = String.fromEnvironment('SHOT_DIR', defaultValue: 'build/shots');
const _flutterRoot =
    String.fromEnvironment('FLUTTER_ROOT', defaultValue: 'C:/src/flutter');
const _emojiFamily = 'ShotEmoji';

Future<void> _loadFonts() async {
  final kanit = FontLoader('Kanit');
  for (final w in ['Light', 'Regular', 'Medium', 'SemiBold']) {
    kanit.addFont(rootBundle.load('assets/fonts/Kanit-$w.ttf'));
  }
  await kanit.load();

  Future<ByteData> file(String path) =>
      File(path).readAsBytes().then((b) => ByteData.view(b.buffer));

  await (FontLoader('MaterialIcons')
        ..addFont(file(
            '$_flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf')))
      .load();
  const emoji = 'C:/Windows/Fonts/seguiemj.ttf';
  if (File(emoji).existsSync()) {
    await (FontLoader(_emojiFamily)..addFont(file(emoji))).load();
  }
}

ThemeData _withEmoji(ThemeData t) => t.copyWith(
      textTheme: t.textTheme.apply(fontFamilyFallback: const [_emojiFamily]),
    );

final _key = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 700));
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final bytes = await tester
      .runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final file = File('$_outDir/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _show(
  WidgetTester tester,
  Harness h,
  Widget screen, {
  required bool dark,
}) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _key,
      child: AppScope(
        data: h.data,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _withEmoji(lightAppTheme),
          darkTheme: _withEmoji(darkAppTheme),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('th', 'TH'),
          supportedLocales: const [Locale('th', 'TH')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: screen,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

ScanRecord _record(String id, List<DetectedIngredient> items, int minutesAgo,
        {bool manual = false}) =>
    ScanRecord(
      id: id,
      createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
      status: ScanStatus.confirmed,
      detected: manual ? const [] : items,
      aiReportedCount: manual ? null : items.length,
      ingredients: items,
      kitchen: const {'oil', 'fish_sauce', 'soy_sauce', 'sugar', 'salt', 'water'},
      manual: manual,
    );

const _onion = DetectedIngredient(id: 'onion', nameTh: 'หอมใหญ่', emoji: '🧅', known: true);

void main() {
  setUpAll(_loadFonts);
  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    PackageInfo.setMockInitialValues(
      appName: 'kinyangdeechao',
      packageName: 'app.kinyangdeechao',
      version: '1.2.0',
      buildNumber: '3',
      buildSignature: '',
    );
  });
  tearDown(() =>
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

  for (final dark in [false, true]) {
    final t = dark ? 'dark' : 'light';

    testWidgets('shots $t', (tester) async {
      addTearDown(tester.view.reset);
      final h = await Harness.create({'settings.onboardingDone': true}, null);
      await h.history.add(_record('a', [egg, _onion], 5));
      await h.history.add(_record('b', [tomato, pork], 150, manual: true));
      await h.history.add(_record('c', [egg], 60 * 30));
      final ai = Recipe(
        id: 'ai-demo',
        nameTh: 'ซุปหัวหอมไข่ลวก',
        description: 'ซุปอุ่น ๆ รสอ่อน หวานธรรมชาติจากหอมใหญ่',
        primaryIngredientId: 'onion',
        category: RecipeCategory.soup,
        ingredients: const [
          RecipeIngredient('หอมใหญ่', ingredientId: 'onion', amount: 2, unit: 'หัว'),
          RecipeIngredient('ไข่ไก่', ingredientId: 'egg', amount: 2, unit: 'ฟอง'),
          RecipeIngredient('น้ำซุป', ingredientId: 'stock', amount: 3, unit: 'ถ้วย'),
        ],
        steps: const ['ต้มน้ำซุป', 'ใส่หอมใหญ่', 'ปรุงรส'],
        isAiGenerated: true,
      );
      await h.favorites.toggle(ai);
      await h.favorites.toggle(RecipeRepository.byId('EGG-01')!);
      final kaprao = RecipeRepository.byId('PORK-01')!;
      await h.shopping.addFromRecipe(kaprao, kaprao.ingredients.take(4));
      await h.shopping.addName('นมสด');
      await h.shopping.toggle(h.shopping.items.last.id);

      await _show(tester, h, OnboardingScreen(onDone: () {}), dark: dark);
      await _shot(tester, '01_onboarding_$t');

      await _show(tester, h, const AppShell(), dark: dark);
      await _shot(tester, '02_scan_$t');
      await tester.tap(find.text('ประวัติ').last);
      await _shot(tester, '03_history_$t');
      await tester.tap(find.text('เมนูโปรด').last);
      await _shot(tester, '04_favorites_$t');
      await tester.tap(find.text('ซื้อของ').last);
      await _shot(tester, '05_shopping_$t');

      // ขั้นตรวจและยืนยัน: AI ตรวจพบไข่+มะเขือเทศ ผู้ใช้แก้ชื่อ 1 รายการและเพิ่มหอมใหญ่
      await h.history.saveDraft(ScanRecord(
        id: 'draft',
        createdAt: DateTime.now(),
        status: ScanStatus.draft,
        detected: [
          egg.withSource(IngredientSource.ai),
          tomato.withSource(IngredientSource.ai),
          const DetectedIngredient(
              id: 'x', nameTh: 'พริกแดง', known: false, source: IngredientSource.ai),
        ],
        aiReportedCount: 3,
        ingredients: [
          egg.withSource(IngredientSource.ai),
          tomato.withSource(IngredientSource.ai),
          _onion.withSource(IngredientSource.user),
        ],
        kitchen: const {'oil', 'fish_sauce', 'salt'},
      ));
      await _show(tester, h, const IngredientReviewScreen(recordId: 'draft'),
          dark: dark);
      await _shot(tester, '06_review_$t');

      await h.history.add(_record('r', [egg, tomato, _onion], 1));
      await _show(tester, h, const IngredientResultScreen(recordId: 'r'),
          dark: dark);
      await _shot(tester, '06b_result_$t');
      await _show(
          tester,
          h,
          const Scaffold(
              body: SafeArea(
                  child: ConditionsForm(initial: CookingConditions.standard))),
          dark: dark);
      await _shot(tester, '06c_conditions_$t');
      await h.settings.setDemoMode(true);
      await _show(tester, h, const AnalysisSummaryScreen(recordId: 'r'),
          dark: dark);
      await _shot(tester, '06d_summary_$t');
      await h.settings.setDemoMode(false);

      final match = const RecipeRepository().matchRecipes(const [egg, tomato]).first;
      await _show(tester, h, RecipeDetailScreen(match: match), dark: dark);
      await _shot(tester, '07_detail_$t');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await _shot(tester, '08_detail_scrolled_$t');

      await _show(tester, h, const SearchScreen(), dark: dark);
      await _shot(tester, '09_browse_$t');

      await _show(
        tester,
        h,
        const Scaffold(
          body: SafeArea(
            child: IngredientPicker(
              initial: [egg, tomato],
              title: 'เลือกวัตถุดิบที่มี',
              confirmLabel: 'ดูเมนูที่ทำได้',
            ),
          ),
        ),
        dark: dark,
      );
      await _shot(tester, '10_picker_$t');

      await _show(tester, h, CookingModeScreen(recipe: kaprao, servings: 2),
          dark: dark);
      await _shot(tester, '11_cooking_$t');

      await _show(tester, h, const SettingsScreen(), dark: dark);
      await _shot(tester, '12_settings_$t');
      await _show(tester, h, const AiSettingsScreen(), dark: dark);
      await _shot(tester, '13_ai_settings_$t');

      if (!dark) {
        await _show(
          tester,
          h,
          Scaffold(
            body: SingleChildScrollView(
              child: Center(child: RecipeShareCard(recipe: kaprao, servings: 2)),
            ),
          ),
          dark: false,
        );
        await _shot(tester, '14_share_card');
      }
    });
  }
}
