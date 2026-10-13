import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/data/catalog/ingredients_catalog.dart';
import 'package:kinyangdeechao/data/recipe_repository.dart';
import 'package:kinyangdeechao/data/recommendation.dart';
import 'package:kinyangdeechao/models/cooking_conditions.dart';
import 'package:kinyangdeechao/models/ingredient.dart';
import 'package:kinyangdeechao/models/ingredient_recognition_result.dart';
import 'package:kinyangdeechao/models/recipe.dart';
import 'package:kinyangdeechao/services/api_service.dart';

import 'test_helpers.dart';

void main() {
  const repo = RecipeRepository();

  group('IngredientCatalog', () {
    test('resolves Thai names, synonyms, English names and ids', () {
      expect(IngredientCatalog.resolve('ไข่ไก่')?.id, 'egg');
      expect(IngredientCatalog.resolve('ไข่')?.id, 'egg');
      expect(IngredientCatalog.resolve('หมูสับ')?.id, 'pork');
      expect(IngredientCatalog.resolve(' Pork ')?.id, 'pork');
      expect(IngredientCatalog.resolve('morning_glory')?.id, 'morning_glory');
      expect(IngredientCatalog.resolve('มาม่า')?.id, 'instant_noodle');
    });

    test('matches whole names only (no substring false positives)', () {
      expect(IngredientCatalog.resolve('ไข่เค็ม'), isNull);
      expect(IngredientCatalog.resolve('หมูยอ'), isNull);
      expect(IngredientCatalog.resolve(''), isNull);
    });

    test('search is prefix-first and hides pantry staples by default', () {
      final r = IngredientCatalog.search('ไข่');
      expect(r.first.id, 'egg');
      expect(IngredientCatalog.search('เกลือ'), isEmpty);
      expect(IngredientCatalog.search('เกลือ', includePantry: true).first.id,
          'salt');
    });

    test('ids and every name are unique across the catalog', () {
      final ids = IngredientCatalog.all.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length);
      final names = <String, String>{};
      for (final i in IngredientCatalog.all) {
        for (final n in [...i.allNames, i.nameEn]) {
          final key = IngredientCatalog.normalize(n);
          expect(names[key] == null || names[key] == i.id, isTrue,
              reason: '"$n" ใช้ซ้ำใน ${names[key]} และ ${i.id}');
          names[key] = i.id;
        }
      }
    });
  });

  group('recipe catalog integrity', () {
    test('has 50+ recipes with unique ids', () {
      final ids = RecipeRepository.recipes.map((r) => r.id).toList();
      expect(ids.length, greaterThanOrEqualTo(50));
      expect(ids.toSet().length, ids.length);
    });

    test('keeps the 15 original ids so old favorites still resolve', () {
      for (final prefix in ['EGG', 'TOMATO', 'POTATO', 'BANANA', 'CARROT']) {
        for (var i = 1; i <= 3; i++) {
          expect(RecipeRepository.byId('$prefix-0$i'), isNotNull);
        }
      }
    });

    test('every recipe is complete and references real ingredients', () {
      for (final r in RecipeRepository.recipes) {
        expect(r.nameTh, isNotEmpty, reason: r.id);
        expect(r.steps.length, greaterThanOrEqualTo(3), reason: r.id);
        expect(r.ingredients.length, greaterThanOrEqualTo(2), reason: r.id);
        expect(findIngredient(r.primaryIngredientId), isNotNull, reason: r.id);
        expect(
          r.ingredients.any((i) => i.ingredientId == r.primaryIngredientId),
          isTrue,
          reason: '${r.id} ต้องมีวัตถุดิบหลักในส่วนผสม',
        );
        for (final i in r.ingredients) {
          if (i.ingredientId != null) {
            expect(findIngredient(i.ingredientId!), isNotNull,
                reason: '${r.id}: ${i.ingredientId}');
          }
        }
        expect(r.servings, greaterThan(0), reason: r.id);
      }
    });

    test('includes northern dishes for the brand', () {
      final northern = RecipeRepository.recipes
          .where((r) => r.has(RecipeTag.northern))
          .map((r) => r.nameTh);
      expect(northern, containsAll(['ไข่ป่าม', 'แกงฮังเล', 'น้ำพริกอ่อง', 'ข้าวซอยไก่']));
    });
  });

  group('IngredientRecognitionResult.fromAiJson', () {
    test('maps known ids and Thai names to catalog entries', () {
      final r = IngredientRecognitionResult.fromAiJson({
        'ingredients': [
          {'id': 'egg', 'name_th': 'ไข่'},
          {'id': 'minced_pork', 'name_th': 'หมูสับ'},
          {'id': 'salted_egg', 'name_th': 'ไข่เค็ม'},
        ],
      });
      expect(r.ingredients.map((i) => i.id), ['egg', 'pork', 'salted_egg']);
      expect(r.ingredients.map((i) => i.known), [true, true, false]);
      expect(r.ingredients[1].nameTh, 'หมู');
    });

    test('keeps detected pantry items (user decides), drops blanks/dupes', () {
      final r = IngredientRecognitionResult.fromAiJson({
        'ingredients': ['salt', 'egg', 'EGG', '', 'unknown', null, 'water'],
      });
      expect(r.ingredients.map((i) => i.id), ['salt', 'egg', 'water']);
      expect(r.ingredients.every((i) => i.source == IngredientSource.ai), isTrue);
      expect(r.skipped, greaterThan(0), reason: 'นับรายการที่ข้าม ไม่ทิ้งเงียบ');
    });

    test('caps at 12 items and cleans control characters', () {
      final r = IngredientRecognitionResult.fromAiJson({
        'ingredients': [
          for (var i = 0; i < 20; i++) {'id': 'x$i', 'name_th': 'ผัก\n$i'},
        ],
      });
      expect(r.ingredients.length, IngredientRecognitionResult.maxIngredients);
      expect(r.ingredients.first.nameTh, 'ผัก 0');
      expect(r.reportedCount, 20);
      expect(r.overLimit, 8, reason: 'ต้องแจ้งผู้ใช้ว่าตัดไปกี่รายการ');
    });

    test('rejects output without an ingredients list or with only bad items', () {
      expect(() => IngredientRecognitionResult.fromAiJson({'ingredient_id': 'tomato'}),
          throwsA(isA<InvalidAiOutput>()));
      expect(() => IngredientRecognitionResult.fromAiJson({'ingredients': 'egg'}),
          throwsA(isA<InvalidAiOutput>()));
      expect(
          () => IngredientRecognitionResult.fromAiJson({
                'ingredients': [1, true, {'id': 5}],
              }),
          throwsA(isA<InvalidAiOutput>()));
      // รายการว่างจริง ๆ = AI ไม่พบอะไร (ไม่ใช่ error)
      expect(IngredientRecognitionResult.fromAiJson({'ingredients': []}).ingredients,
          isEmpty);
    });
  });

  group('matchRecipes', () {
    test('eggs + tomato: a dish that uses both and needs nothing ranks first', () {
      final ranked = rankRecommendations(
          repo.matchRecipes([egg, tomato]), CookingConditions.standard);
      final first = ranked.first.match;
      expect(first.need, isEmpty);
      expect(first.coverage, 1);
      expect(first.haveCore.map((i) => i.ingredientId), containsAll(['egg', 'tomato']));
    });

    test('ingredients outside the old 5 now count (pork → กะเพรา)', () {
      final m = repo.matchRecipes([pork]);
      expect(m.map((x) => x.recipe.id), contains('PORK-01'));
      final kaprao = m.firstWhere((x) => x.recipe.id == 'PORK-01');
      expect(kaprao.haveNames, contains('หมูสับ'));
    });

    test('pantry staples are never listed as missing', () {
      final m = repo.matchRecipes([egg]);
      for (final x in m) {
        expect(x.need.where((i) => i.isPantry), isEmpty, reason: x.recipe.id);
      }
    });

    test('a recipe using the item only as a minor ingredient is filtered out', () {
      // มีแค่ต้นหอม ไม่ควรได้ "ไข่เจียว" (ต้นหอมเป็นแค่ของเสริม)
      final m = repo.matchRecipes(
          [DetectedIngredient.fromCatalog(IngredientCatalog.byId('spring_onion')!)]);
      expect(m.map((x) => x.recipe.id), isNot(contains('EGG-01')));
    });

    test('unknown names match recipe ingredients by exact name', () {
      final r = Recipe(
        id: 'T',
        nameTh: 'ทดสอบ',
        primaryIngredientId: '',
        ingredients: const [RecipeIngredient('ไข่เค็ม'), RecipeIngredient('ข้าวสวย', ingredientId: 'rice')],
        steps: const ['a', 'b', 'c'],
      );
      final m = matchAiRecipe(r, [DetectedIngredient.fromName('ไข่เค็ม')]);
      expect(m.haveNames, ['ไข่เค็ม']);
      expect(m.needNames, ['ข้าวสวย']);
      // "ไข่" ไม่ทำให้ "ไข่เค็ม" กลายเป็นของที่มี
      final m2 = matchAiRecipe(r, [egg]);
      expect(m2.have, isEmpty);
    });

    test('empty input returns no matches', () {
      expect(repo.matchRecipes(const []), isEmpty);
    });
  });

  group('search & browse', () {
    test('search by dish name comes before search by ingredient', () {
      final r = repo.search('ไข่');
      expect(r, isNotEmpty);
      expect(r.first.recipe.nameTh, contains('ไข่'));
    });

    test('search by a synonym finds recipes using that ingredient', () {
      final r = repo.search('หมูสับ').map((m) => m.recipe.id);
      expect(r, contains('PORK-01'));
    });

    test('filters narrow results', () {
      final veg = repo.browse(const RecipeFilter(vegetarian: true));
      expect(veg, isNotEmpty);
      expect(veg.every((r) => r.has(RecipeTag.vegetarian)), isTrue);
      final quick = repo.browse(const RecipeFilter(maxMinutes: 15));
      expect(quick.every((r) => r.totalMinutes <= 15), isTrue);
      final noSpicy = repo.browse(const RecipeFilter(notSpicy: true));
      expect(noSpicy.any((r) => r.has(RecipeTag.spicy)), isFalse);
    });

    test('daily picks are stable for a given day', () {
      final d = DateTime(2026, 10, 12);
      expect(repo.dailyPicks(now: d).map((r) => r.id),
          repo.dailyPicks(now: d).map((r) => r.id));
      expect(repo.dailyPicks(now: d).length, 6);
    });
  });

  group('amounts', () {
    test('formatAmount renders friendly fractions', () {
      expect(formatAmount(2), '2');
      expect(formatAmount(0.5), '½');
      expect(formatAmount(1.5), '1½');
      expect(formatAmount(0.25), '¼');
      expect(formatAmount(1.2), '1.2');
    });

    test('amountLabel scales with servings', () {
      const i = RecipeIngredient('ไข่ไก่', ingredientId: 'egg', amount: 2, unit: 'ฟอง');
      expect(i.amountLabel(), '2 ฟอง');
      expect(i.amountLabel(1.5), '3 ฟอง');
      expect(const RecipeIngredient('เกลือ').amountLabel(), 'ตามชอบ');
    });
  });

  group('ApiService parsing', () {
    test('decodeJsonObject tolerates fences and surrounding text', () {
      final j = ApiService.decodeJsonObject(
          'Sure! ```json\n{"ingredients": ["egg"]}\n``` hope it helps');
      expect(j['ingredients'], ['egg']);
    });

    test('decodeJsonObject throws invalidResponse on garbage', () {
      expect(
        () => ApiService.decodeJsonObject('no json here'),
        throwsA(isA<RecognitionException>().having(
            (e) => e.type, 'type', RecognitionErrorType.invalidResponse)),
      );
    });

    test('parseAiRecipe builds a rich recipe with unique ids', () {
      final raw = {
        'name_th': 'ไข่ต้มซีอิ๊ว',
        'category': 'main',
        'difficulty': 'easy',
        'prep_minutes': 5,
        'cook_minutes': 10,
        'servings': 2,
        'kcal_per_serving': 200,
        'ingredients': [
          {'name': 'ไข่ไก่', 'amount': 4, 'unit': 'ฟอง'},
          {'name': 'ซีอิ๊ว', 'amount': null, 'unit': null},
          'ต้นหอม',
        ],
        'steps': ['ต้มไข่', 'ปอกเปลือก', 'ราดซีอิ๊ว'],
      };
      final a = ApiService.parseAiRecipe(raw).recipe!;
      final b = ApiService.parseAiRecipe(raw).recipe!;
      expect(a.isAiGenerated, isTrue);
      expect(a.id, isNot(b.id));
      expect(a.favoriteKey, a.id);
      expect(a.primaryIngredientId, 'egg');
      expect(a.ingredients.first.amountLabel(), '4 ฟอง');
      expect(a.ingredients[1].isPantry, isTrue);
      expect(a.totalMinutes, 15);
      expect(a.timeKnown, isTrue);
      expect(a.kcalPerServing, isNull, reason: 'ไม่ใช้ kcal ที่ AI เดา');
      expect(a.sourceLabel, 'สูตรจาก AI');
    });

    test('parseAiRecipe rejects incomplete items with a reason', () {
      expect(ApiService.parseAiRecipe({'name_th': 'x'}).problem, isNotNull);
      expect(ApiService.parseAiRecipe('nope').problem, 'ไม่ใช่ object');
      expect(
          ApiService.parseAiRecipe({
            'name_th': 'x',
            'ingredients': ['ไข่', 'ข้าว'],
            'steps': ['ทำ'],
          }).problem,
          contains('ขั้นตอน'));
      expect(
          ApiService.parseAiRecipe({
            'name_th': 'x',
            'ingredients': [
              'ไข่',
              {'name': 5},
              {'name': 'ข้าว', 'amount': 'หนึ่งถ้วย'},
            ],
            'steps': ['a', 'b'],
          }).problem,
          contains('ส่วนผสม'),
          reason: 'รายการที่ชนิดข้อมูลผิดไม่นับ');
    });

    test('parseAiRecipe: unknown time stays unknown, servings follow request', () {
      final r = ApiService.parseAiRecipe({
        'name_th': 'ข้าวไข่เค็ม',
        'ingredients': ['ไข่เค็ม', 'ข้าวสวย'],
        'steps': ['a', 'b'],
        'prep_minutes': 'ไม่รู้',
        'equipment': ['pan'],
        'spicy': false,
      }, requestedServings: 4).recipe!;
      expect(r.timeKnown, isFalse);
      expect(r.servings, 4);
      expect(r.equipment, {Equipment.pan});
      expect(r.isSpicy, isFalse);
    });
  });
}
