import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:kinyangdeechao/constants/app_constants.dart';
import 'package:kinyangdeechao/core/formatters.dart';
import 'package:kinyangdeechao/data/image_store.dart';
import 'package:kinyangdeechao/data/recipe_repository.dart';
import 'package:kinyangdeechao/models/ai_trace.dart';
import 'package:kinyangdeechao/models/cooking_conditions.dart';
import 'package:kinyangdeechao/models/ingredient.dart';
import 'package:kinyangdeechao/models/recipe.dart';
import 'package:kinyangdeechao/models/scan_record.dart';
import 'package:kinyangdeechao/models/shopping_item.dart';
import 'package:kinyangdeechao/state/shopping_controller.dart' show AddNameResult;

import 'test_helpers.dart';

ScanRecord _record(String id, {String? image}) => ScanRecord(
      id: id,
      createdAt: DateTime(2026, 1, 1),
      imageFile: image ?? '$id.jpg',
      ingredients: const [egg],
    );

void main() {
  group('JSON round-trips & migration', () {
    test('ScanRecord keeps everything', () {
      final ai = RecipeRepository.byId('EGG-01')!;
      final r = ScanRecord(
        id: '1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        imageFile: '1.png',
        status: ScanStatus.confirmed,
        detected: const [egg, tomato],
        aiReportedCount: 14,
        ingredients: const [
          egg,
          DetectedIngredient(
              id: 'x', nameTh: 'ไข่เค็ม', known: false, source: IngredientSource.user),
        ],
        renames: const [IngredientRename('มะเขือเทศ', 'ไข่เค็ม')],
        kitchen: const {'oil'},
        confirmedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        conditions: const CookingConditions(
            maxMinutes: 15, servings: 3, equipment: {Equipment.pan}, spice: SpicePreference.mild),
        ai: AiRecipeCache(recipes: [ai], inputKey: 'k', createdAt: DateTime(2026)),
        traces: [fakeTrace(AiTraceKind.recognize)],
      );
      final back = ScanRecord.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(back.imageFile, '1.png');
      expect(back.status, ScanStatus.confirmed);
      expect(back.detected.map((i) => i.id), ['egg', 'tomato']);
      expect(back.aiReportedCount, 14);
      expect(back.ingredients.map((i) => i.nameTh), ['ไข่ไก่', 'ไข่เค็ม']);
      expect(back.ingredients.last.source, IngredientSource.user);
      expect(back.renames.single, const IngredientRename('มะเขือเทศ', 'ไข่เค็ม'));
      expect(back.changes.renamed.single.to, 'ไข่เค็ม');
      expect(back.kitchen, {'oil'});
      expect(back.conditions, r.conditions);
      expect(back.ai!.inputKey, 'k');
      expect(back.aiRecipes.single.ingredients.length, ai.ingredients.length);
      expect(back.traces.single.durationMs, 1200);
    });

    test('pre-1.2 records: photo → legacy (needs review), manual → confirmed', () {
      final photo = ScanRecord.fromJson({
        'id': 'p',
        'createdAt': 0,
        'imageFile': 'p.jpg',
        'ingredients': [egg.toJson()],
        'aiRecipes': [RecipeRepository.byId('EGG-01')!.toJson()],
      });
      expect(photo.status, ScanStatus.legacy);
      expect(photo.isConfirmed, isFalse);
      expect(photo.detected.single.id, 'egg');
      expect(photo.ai!.inputKey, isNull, reason: 'ไม่รู้ว่าขอจาก input ใด → ผลเก่า');
      final manual = ScanRecord.fromJson({
        'id': 'm',
        'createdAt': 0,
        'manual': true,
        'ingredients': [egg.toJson()],
      });
      expect(manual.status, ScanStatus.confirmed);
      expect(manual.detected, isEmpty);
    });

    test('old records with absolute imagePath keep only the file name', () {
      final r = ScanRecord.fromJson({
        'id': 'a',
        'createdAt': 0,
        'imagePath': '/data/user/0/com.example.kinyangdeechao/app_flutter/scans/a.jpg',
        'ingredients': [
          {'id': 'onion', 'nameTh': 'หอมใหญ่', 'known': false},
        ],
      });
      expect(r.imageFile, 'a.jpg');
      // วัตถุดิบที่ตอนนี้มีในฐานข้อมูลแล้วถูกยกระดับเป็น known
      expect(r.ingredients.single.known, isTrue);
      expect(r.ingredients.single.emoji, isNotNull);
      expect(fileNameOf(r'C:\x\scans\b.jpg'), 'b.jpg');
    });

    test('v1 recipe JSON (string ingredients, no primary) migrates', () {
      final r = recipeFromJson({
        'id': 'EGG-01',
        'nameTh': 'ไข่เจียวหมูสับ',
        'primaryIngredientId': 'egg',
        'ingredients': ['หมูสับ', 'น้ำปลา'],
        'steps': ['a', 'b'],
      });
      expect(r.ingredients.first.ingredientId, 'egg');
      expect(r.ingredients.map((i) => i.ingredientId), ['egg', 'pork', 'fish_sauce']);
      expect(r.servings, 2);
    });

    test('v1 AI recipe keeps legacy favorite key', () {
      final r = recipeFromJson({
        'id': 'AI-1',
        'nameTh': 'ซุปหัวหอม',
        'ingredients': ['หอมใหญ่'],
        'steps': ['a'],
        'isAiGenerated': true,
      });
      expect(r.favoriteKey, 'ai:ซุปหัวหอม');
    });
  });

  group('HistoryController', () {
    test('keeps at most 100 records and deletes overflow images', () async {
      final h = await Harness.create();
      for (var i = 0; i < 102; i++) {
        await h.history.add(_record('$i'));
      }
      expect(h.history.records.length, 100);
      expect(h.images.deleted, ['0.jpg', '1.jpg']);
    });

    test('remove is synchronous and undo restores position', () async {
      final h = await Harness.create();
      for (final id in ['a', 'b', 'c']) {
        await h.history.add(_record(id));
      }
      h.history.remove('b');
      expect(h.history.records.map((r) => r.id), ['c', 'a']);
      await h.history.undoRemoval('b');
      expect(h.history.records.map((r) => r.id), ['c', 'b', 'a']);
      expect(h.images.deleted, isEmpty);
    });

    test('two quick deletes never delete the wrong image (regression)', () async {
      final h = await Harness.create();
      for (final id in ['a', 'b', 'c']) {
        await h.history.add(_record(id));
      }
      h.history.remove('a');
      h.history.remove('b');
      // snackbar ของ a ปิด (หมดเวลา) ขณะที่ b ยังรอเลิกทำ
      await h.history.finalizeRemoval('a');
      expect(h.images.deleted, ['a.jpg']);
      await h.history.undoRemoval('b');
      expect(h.history.byId('b'), isNotNull);
      expect(h.images.deleted, ['a.jpg']);
    });

    test('confirm after edit keeps AI recipes but they no longer match the input',
        () async {
      final h = await Harness.create();
      await h.history.add(_record('a'));
      await h.history.saveAiRecipes(
          'a',
          AiRecipeCache(
              recipes: [RecipeRepository.byId('EGG-01')!], inputKey: 'old-key'));
      final ok = await h.history.confirm('a',
          ingredients: const [tomato], renames: const [], kitchen: const {'oil'});
      expect(ok, isTrue);
      final r = h.history.byId('a')!;
      expect(r.ingredients, const [tomato]);
      expect(r.status, ScanStatus.confirmed);
      expect(r.ai!.inputKey, 'old-key');
    });

    test('draft is stored separately and discarding deletes its image', () async {
      final h = await Harness.create();
      final d = _record('d').copyWith(status: ScanStatus.draft);
      await h.history.saveDraft(d);
      expect(h.history.records, isEmpty);
      expect(h.history.draft!.id, 'd');
      // เปิดแอปใหม่ → draft ยังอยู่ (กู้คืนได้) และไม่อยู่ในประวัติ
      final again = await Harness.create({
        for (final k in h.prefs.getKeys()) k: h.prefs.get(k)!,
      });
      expect(again.history.draft!.id, 'd');
      expect(again.history.records, isEmpty);
      await h.history.discardDraft();
      expect(h.history.draft, isNull);
      expect(h.images.deleted, ['d.jpg']);
    });

    test('a new draft replaces the old one and deletes the old image', () async {
      final h = await Harness.create();
      await h.history.saveDraft(_record('d1'));
      await h.history.saveDraft(_record('d2'));
      expect(h.history.draft!.id, 'd2');
      expect(h.images.deleted, ['d1.jpg']);
    });

    test('cleanupOrphans removes only files nothing refers to', () async {
      final h = await Harness.create();
      await h.history.add(_record('keep'));
      await h.history.saveDraft(_record('draft'));
      h.images.files.addAll(['keep.jpg', 'draft.jpg', 'orphan.jpg']);
      final removed = await h.history.cleanupOrphans();
      expect(removed, 1);
      expect(h.images.deleted, ['orphan.jpg']);
    });

    test('a failed write is reported (UI must not claim success)', () async {
      final h = await Harness.create();
      h.failWrites();
      expect(await h.history.add(_record('a')), isFalse);
      expect(h.history.lastSaveFailed, isTrue);
      expect(await h.shopping.addName('ไข่'), AddNameResult.saveFailed);
      expect(await h.shopping.addFromRecipe(
          RecipeRepository.byId('EGG-01')!, RecipeRepository.byId('EGG-01')!.ingredients), isNull);
    });

    test('late snackbar callbacks after undo or clear do nothing', () async {
      final h = await Harness.create();
      await h.history.add(_record('a'));
      h.history.remove('a');
      await h.history.undoRemoval('a');
      await h.history.finalizeRemoval('a'); // snackbar ปิดช้าหลังกดเลิกทำ
      expect(h.images.deleted, isEmpty);
      expect(h.history.byId('a'), isNotNull);
      h.history.remove('a');
      await h.history.clear();
      await h.history.finalizeRemoval('a');
      expect(h.images.deleted, ['a.jpg']);
    });

    test('persists and survives corrupted entries', () async {
      final h = await Harness.create({
        'history.v1': jsonEncode([
          _record('ok').toJson(),
          {'broken': true},
        ]),
      });
      expect(h.history.records.map((r) => r.id), ['ok']);
      final bad = await Harness.create({'history.v1': '{not json'});
      expect(bad.history.isEmpty, isTrue);
    });
  });

  group('FavoritesController', () {
    test('toggle and persist', () async {
      final h = await Harness.create();
      final r = RecipeRepository.byId('EGG-01')!;
      expect(await h.favorites.toggle(r), (isFavorite: true, saved: true));
      expect(h.favorites.isFavorite(r), isTrue);
      expect(h.prefs.getString('favorites.v1'), contains('EGG-01'));
      expect(await h.favorites.toggle(r), (isFavorite: false, saved: true));
      expect(h.favorites.isEmpty, isTrue);
    });

    test('saved built-in recipes are refreshed from the catalog', () async {
      final h = await Harness.create({
        'favorites.v1': jsonEncode([
          {
            'id': 'EGG-01',
            'nameTh': 'ชื่อเก่า',
            'primaryIngredientId': 'egg',
            'ingredients': ['หมูสับ'],
            'steps': ['a'],
          },
        ]),
      });
      final r = h.favorites.recipes.single;
      expect(r.nameTh, RecipeRepository.byId('EGG-01')!.nameTh);
      expect(r.kcalPerServing, isNotNull);
    });

    test('two different AI recipes with the same name are separate', () async {
      final h = await Harness.create();
      Recipe ai(String id) => Recipe(
            id: id,
            nameTh: 'ผัดผัก',
            primaryIngredientId: '',
            ingredients: const [RecipeIngredient('ผัก')],
            steps: const ['a'],
            isAiGenerated: true,
          );
      await h.favorites.toggle(ai('ai-1'));
      await h.favorites.toggle(ai('ai-2'));
      expect(h.favorites.recipes.length, 2);
    });
  });

  group('ShoppingController', () {
    test('adds missing recipe ingredients, de-duplicates and tracks recipes', () async {
      final h = await Harness.create();
      final a = RecipeRepository.byId('EGG-01')!;
      final b = RecipeRepository.byId('EGG-02')!;
      final added = await h.shopping.addFromRecipe(a, a.ingredients.take(2));
      expect(added, 2);
      final again = await h.shopping.addFromRecipe(b, b.ingredients.take(1));
      expect(again, 0);
      final eggItem = h.shopping.items.firstWhere((i) => i.ingredientId == 'egg');
      expect(eggItem.recipes, [a.nameTh, b.nameTh]);
      // หน่วยเดียวกันรวมกัน (2 ฟองจากแต่ละสูตร)
      expect(eggItem.amount, '4 ฟอง');
    });

    test('different units are kept apart; re-adding a recipe does not double', () async {
      final h = await Harness.create();
      Recipe r(String id, double amount, String unit) => Recipe(
            id: id,
            nameTh: id,
            primaryIngredientId: 'pork',
            ingredients: [RecipeIngredient('หมูสับ', ingredientId: 'pork', amount: amount, unit: unit)],
            steps: const ['a', 'b'],
          );
      final a = r('A', 100, 'กรัม');
      final b = r('B', 1, 'ถ้วย');
      await h.shopping.addFromRecipe(a, a.ingredients);
      await h.shopping.addFromRecipe(b, b.ingredients);
      expect(h.shopping.items.single.amount, '100 กรัม + 1 ถ้วย');
      await h.shopping.addFromRecipe(a, a.ingredients, factor: 2);
      expect(h.shopping.items.single.amount, '200 กรัม + 1 ถ้วย',
          reason: 'สูตรเดิมแทนที่ปริมาณเดิม ไม่บวกซ้ำ');
    });

    test('scales amounts by servings factor', () async {
      final h = await Harness.create();
      final a = RecipeRepository.byId('EGG-01')!;
      await h.shopping.addFromRecipe(a, a.ingredients.take(1), factor: 2);
      expect(h.shopping.items.single.amount, '4 ฟอง');
    });

    test('typed items resolve to catalog and reject duplicates', () async {
      final h = await Harness.create();
      expect(await h.shopping.addName('ไข่'), AddNameResult.added);
      expect(h.shopping.items.single.name, 'ไข่ไก่');
      expect(await h.shopping.addName('ไข่ไก่'), AddNameResult.duplicate);
      expect(await h.shopping.addName('  '), AddNameResult.empty);
      expect(await h.shopping.addName('ขนมจีน'), AddNameResult.added);
      expect(h.shopping.grouped.keys,
          containsAll([IngredientCategory.dairy, IngredientCategory.other]));
    });

    test('toggle, clear checked, remove/undo and share text', () async {
      final h = await Harness.create();
      await h.shopping.addName('ไข่');
      await h.shopping.addName('หมู');
      final eggId = h.shopping.items.firstWhere((i) => i.name == 'ไข่ไก่').id;
      await h.shopping.toggle(eggId);
      expect(h.shopping.remaining, 1);
      expect(h.shopping.shareText(), contains('หมู'));
      expect(h.shopping.shareText(), isNot(contains('ไข่ไก่')));
      expect(await h.shopping.clearChecked(), (removed: 1, saved: true));
      final porkId = h.shopping.items.single.id;
      h.shopping.remove(porkId);
      expect(h.shopping.isEmpty, isTrue);
      await h.shopping.undoRemoval(porkId);
      expect(h.shopping.items.single.name, 'หมู');
    });

    test('persists across controllers', () async {
      final h = await Harness.create();
      await h.shopping.addName('ไข่');
      final raw = h.prefs.getString('shopping.v1')!;
      final items = (jsonDecode(raw) as List)
          .map((e) => ShoppingItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      expect(items.single.ingredientId, 'egg');
    });
  });

  group('AiConfigController', () {
    test('user key wins, URL/model fall back to defaults', () async {
      final h = await Harness.create({}, null);
      expect(h.ai.hasUserKey, isFalse);
      expect(h.ai.hasKey, AppConstants.apiKey.isNotEmpty);
      await h.ai.save(apiKey: ' k1 ', baseUrl: '', model: 'm');
      expect(h.ai.config.apiKey, 'k1');
      expect(h.ai.config.baseUrl, AppConstants.apiBaseUrl);
      expect(h.ai.config.model, 'm');
      expect(await h.secrets.read('ai.apiKey'), 'k1');
      expect(h.prefs.getString('ai.apiKey'), isNull,
          reason: 'key ต้องไม่อยู่ใน SharedPreferences');
      await h.ai.clearKey();
      expect(h.ai.hasUserKey, isFalse);
      expect(await h.secrets.read('ai.apiKey'), isNull);
    });
  });

  group('SettingsController', () {
    test('theme, haptics and onboarding persist', () async {
      final h = await Harness.create();
      await h.settings.setThemeMode(ThemeMode.dark);
      await h.settings.setHaptics(false);
      await h.settings.completeOnboarding();
      final again = await Harness.create({
        'settings.themeMode': h.prefs.getString('settings.themeMode')!,
        'settings.haptics': false,
        'settings.onboardingDone': true,
      });
      expect(again.settings.themeMode, ThemeMode.dark);
      expect(again.settings.hapticsEnabled, isFalse);
      expect(again.settings.onboardingDone, isTrue);
    });
  });

  group('ImageStore (real files)', () {
    test('saves by file name, resolves path, keeps extension, deletes', () async {
      final base = makeTempDir();
      addTearDown(() => base.deleteSync(recursive: true));
      final src = File('${base.path}/src.png')..writeAsBytesSync([1, 2, 3]);
      final store = ImageStore(baseDir: () async => base);
      await store.init();

      final name = await store.save(XFile(src.path, mimeType: 'image/png'), 'r1');
      expect(name, 'r1.png');
      final path = store.pathFor(name)!;
      expect(File(path).existsSync(), isTrue);
      expect(store.pathFor(null), isNull);

      // ชื่อที่พยายามออกนอกโฟลเดอร์ถูกปฏิเสธ
      await store.delete('../src.png');
      expect(src.existsSync(), isTrue);
      expect(await store.listFiles(), [name]);
      expect(await store.exists(name), isTrue);

      await store.delete(name);
      expect(File(path).existsSync(), isFalse);
      expect(await store.exists(name), isFalse);
      await store.save(XFile(src.path), 'r2');
      await store.deleteAll();
      expect(Directory('${base.path}/scans').existsSync(), isFalse);
    });

    test('save returns null when the source is missing', () async {
      final base = makeTempDir();
      addTearDown(() => base.deleteSync(recursive: true));
      final store = ImageStore(baseDir: () async => base);
      expect(await store.save(XFile('${base.path}/nope.jpg'), 'x'), isNull);
    });
  });

  group('formatRelativeThai', () {
    final now = DateTime(2026, 10, 12, 15, 0);
    test('covers all ranges', () {
      expect(formatRelativeThai(now, now: now), 'เมื่อสักครู่');
      expect(formatRelativeThai(now.subtract(const Duration(minutes: 5)), now: now),
          '5 นาทีที่แล้ว');
      expect(formatRelativeThai(now.subtract(const Duration(hours: 2)), now: now),
          '2 ชม.ที่แล้ว');
      expect(formatRelativeThai(DateTime(2026, 10, 11, 9, 5), now: now),
          'เมื่อวาน 09:05');
      expect(formatRelativeThai(DateTime(2026, 10, 8), now: now), '4 วันที่แล้ว');
      expect(formatRelativeThai(DateTime(2026, 1, 3), now: now), '3 ม.ค. 2569');
    });
  });
}
