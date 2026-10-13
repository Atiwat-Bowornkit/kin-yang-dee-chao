import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/data/catalog/ingredients_catalog.dart';
import 'package:kinyangdeechao/data/recipe_repository.dart';
import 'package:kinyangdeechao/data/recommendation.dart';
import 'package:kinyangdeechao/models/cooking_conditions.dart';
import 'package:kinyangdeechao/models/ingredient.dart';
import 'package:kinyangdeechao/models/recipe.dart';
import 'package:kinyangdeechao/services/api_service.dart';
import 'package:kinyangdeechao/state/ai_config_controller.dart';

import 'test_helpers.dart';

DetectedIngredient _cat(String id) =>
    DetectedIngredient.fromCatalog(IngredientCatalog.byId(id)!);

Recipe _r(
  String id, {
  List<RecipeIngredient> ingredients = const [
    RecipeIngredient('ไข่ไก่', ingredientId: 'egg', amount: 2, unit: 'ฟอง'),
    RecipeIngredient('มะเขือเทศ', ingredientId: 'tomato', amount: 1, unit: 'ลูก'),
  ],
  int prep = 5,
  int cook = 10,
  bool timeKnown = true,
  Set<Equipment>? equipment = const {Equipment.pan},
  Set<RecipeTag> tags = const {},
  bool ai = false,
  bool? spicy,
}) =>
    Recipe(
      id: id,
      nameTh: id,
      primaryIngredientId: 'egg',
      ingredients: ingredients,
      steps: const ['a', 'b'],
      prepMinutes: prep,
      cookMinutes: cook,
      timeKnown: timeKnown,
      equipment: equipment,
      tags: tags,
      isAiGenerated: ai,
      spicyFlag: spicy,
    );

void main() {
  group('negative matching (ชื่อคล้ายกันต้องไม่ถือว่ามี)', () {
    test('catalog keeps look-alike names apart', () {
      expect(IngredientCatalog.resolve('ปลา')?.id, 'fish');
      expect(IngredientCatalog.resolve('น้ำปลา')?.id, 'fish_sauce');
      expect(IngredientCatalog.resolve('ไก่')?.id, 'chicken');
      expect(IngredientCatalog.resolve('ไข่ไก่')?.id, 'egg');
      expect(IngredientCatalog.resolve('ไข่เค็ม'), isNull);
      expect(IngredientCatalog.resolve('ไข่เป็ด'), isNull,
          reason: 'ไม่ใช่ชื่อพ้องของไข่ไก่');
      expect(IngredientCatalog.resolve('เลมอน'), isNull,
          reason: 'ไม่ใช่ชื่อพ้องของมะนาว');
    });

    final recipe = _r('NEG', ingredients: const [
      RecipeIngredient('น้ำปลา', ingredientId: 'fish_sauce'),
      RecipeIngredient('ไข่เค็ม'),
      RecipeIngredient('ไข่ไก่', ingredientId: 'egg'),
    ]);

    test('ปลา ≠ น้ำปลา', () {
      final m = matchAiRecipe(recipe, [_cat('fish')]);
      expect(m.have, isEmpty);
      expect(m.staples, isEmpty);
      expect(m.pantryNeed.map((i) => i.name), ['น้ำปลา']);
    });

    test('ไข่ไก่ ≠ ไข่เค็ม', () {
      final m = matchAiRecipe(recipe, [egg]);
      expect(m.haveNames, ['ไข่ไก่']);
      expect(m.needNames, ['ไข่เค็ม']);
    });

    test('ไก่ ≠ ไข่ไก่', () {
      final m = matchAiRecipe(recipe, [_cat('chicken')]);
      expect(m.have, isEmpty);
      expect(m.needNames, containsAll(['ไข่เค็ม', 'ไข่ไก่']));
    });
  });

  group('ingredient completeness x/y', () {
    final recipe = _r('XY', ingredients: const [
      RecipeIngredient('ไข่ไก่', ingredientId: 'egg'),
      RecipeIngredient('มะเขือเทศ', ingredientId: 'tomato'),
      RecipeIngredient('น้ำปลา', ingredientId: 'fish_sauce'),
      RecipeIngredient('ต้นหอม', ingredientId: 'spring_onion', optional: true),
    ]);

    test('pantry items never count toward x/y, kitchen choice decides staples', () {
      final withKitchen = matchAiRecipe(recipe, [egg], kitchen: {'fish_sauce'});
      expect(withKitchen.haveCore.length, 1);
      expect(withKitchen.coreTotal, 2);
      expect(withKitchen.staples.map((i) => i.name), ['น้ำปลา']);
      expect(withKitchen.pantryNeed, isEmpty);
      expect(withKitchen.toPrepare.map((i) => i.name), ['มะเขือเทศ']);

      final noKitchen = matchAiRecipe(recipe, [egg]);
      expect(noKitchen.coreTotal, 2);
      expect(noKitchen.staples, isEmpty,
          reason: 'ไม่ถือว่ามีของในครัวถ้าผู้ใช้ไม่ได้เลือก');
      expect(noKitchen.toPrepare.map((i) => i.name), ['มะเขือเทศ', 'น้ำปลา']);
      expect(noKitchen.optional.single.name, 'ต้นหอม');
    });

    test('a recipe with only pantry items does not divide by zero', () {
      final m = matchAiRecipe(
          _r('P', ingredients: const [
            RecipeIngredient('น้ำปลา', ingredientId: 'fish_sauce'),
            RecipeIngredient('น้ำตาล', ingredientId: 'sugar'),
          ]),
          const []);
      expect(m.coreTotal, 0);
      expect(m.coverage, 1);
      expect(RecommendationExplanation.of(m, CookingConditions.standard).coverageLabel,
          'สูตรนี้ไม่มีวัตถุดิบหลักที่ต้องใช้');
    });

    test('coverage label reports counts, never a confidence percentage', () {
      final e = RecommendationExplanation.of(
          matchAiRecipe(recipe, [egg]), CookingConditions.standard);
      expect(e.coverageLabel, 'มีวัตถุดิบหลัก 1/2 อย่าง');
      expect(e.coverageLabel, isNot(contains('%')));
    });
  });

  group('evaluateConditions', () {
    test('conditions that were not set are not checked', () {
      expect(evaluateConditions(_r('A'), CookingConditions.standard), isEmpty);
    });

    test('time: pass, fail, and unknown when time is not known', () {
      const c = CookingConditions(maxMinutes: 15);
      expect(evaluateConditions(_r('A', prep: 5, cook: 10), c).single.status,
          CheckStatus.pass);
      expect(evaluateConditions(_r('A', prep: 5, cook: 11), c).single.status,
          CheckStatus.fail);
      expect(
          evaluateConditions(_r('A', ai: true, timeKnown: false), c).single.status,
          CheckStatus.unknown);
    });

    test('equipment: missing tool fails, no-stove passes, unspecified is unknown', () {
      const panOnly = CookingConditions(equipment: {Equipment.pan});
      expect(
          evaluateConditions(_r('A', equipment: {Equipment.oven}), panOnly)
              .single
              .detail,
          contains('เตาอบ'));
      expect(
          evaluateConditions(_r('A', equipment: {Equipment.oven}), panOnly)
              .single
              .status,
          CheckStatus.fail);
      const noStove = CookingConditions(equipment: {});
      expect(evaluateConditions(_r('A', equipment: {}), noStove).single.status,
          CheckStatus.pass);
      expect(evaluateConditions(_r('A', equipment: null), noStove).single.status,
          CheckStatus.unknown);
    });

    test('spice: curated tag, AI flag, AI unknown', () {
      const mild = CookingConditions(spice: SpicePreference.mild);
      expect(evaluateConditions(_r('A', tags: {RecipeTag.spicy}), mild).single.status,
          CheckStatus.fail);
      expect(evaluateConditions(_r('A'), mild).single.status, CheckStatus.pass);
      expect(evaluateConditions(_r('A', ai: true, spicy: false), mild).single.status,
          CheckStatus.pass);
      expect(evaluateConditions(_r('A', ai: true), mild).single.status,
          CheckStatus.unknown);
    });
  });

  group('rankRecommendations', () {
    test('deterministic order: fails → coverage → missing → unknown → time → id',
        () {
      const c = CookingConditions(maxMinutes: 15);
      final full = matchAiRecipe(_r('B-full'), [egg, tomato]);
      final fullSlow = matchAiRecipe(_r('A-slow', cook: 30), [egg, tomato]);
      final half = matchAiRecipe(_r('C-half'), [egg]);
      final unknown = matchAiRecipe(_r('D-unknown', ai: true, timeKnown: false), [egg, tomato]);
      final tieQuick = matchAiRecipe(_r('A-tie', prep: 1, cook: 1), [egg, tomato]);

      final input = [fullSlow, half, unknown, full, tieQuick];
      final ids = [for (final e in rankRecommendations(input, c)) e.recipe.id];
      expect(ids, ['A-tie', 'B-full', 'D-unknown', 'C-half', 'A-slow']);
      // ลำดับเข้าต่างกัน ผลต้องเหมือนเดิม
      final again = [
        for (final e in rankRecommendations(input.reversed.toList(), c)) e.recipe.id
      ];
      expect(again, ids);
    });

    test('real catalog ranking is stable across runs', () {
      const repo = RecipeRepository();
      List<String> run() => [
            for (final e in rankRecommendations(
                repo.matchRecipes([egg, tomato, pork], kitchen: {'oil'}),
                const CookingConditions(maxMinutes: 30, spice: SpicePreference.mild)))
              e.recipe.id
          ];
      expect(run(), run());
    });
  });

  group('AI suggestion cache key', () {
    const config = AiConfig(apiKey: 'k', baseUrl: 'https://ai.example/v1', model: 'm1');
    String key({
      List<DetectedIngredient> owned = const [egg, tomato],
      Set<String> kitchen = const {'oil'},
      CookingConditions conditions = CookingConditions.standard,
      AiConfig cfg = config,
    }) =>
        ApiService.suggestionInputKey(
            owned: owned, kitchen: kitchen, conditions: conditions, config: cfg);

    test('same input → same key regardless of order', () {
      expect(key(owned: const [tomato, egg]), key());
    });

    test('ingredients, kitchen, conditions or model change the key', () {
      final base = key();
      expect(key(owned: const [egg]), isNot(base));
      expect(key(kitchen: const {'oil', 'salt'}), isNot(base));
      expect(key(conditions: const CookingConditions(servings: 4)), isNot(base));
      expect(key(conditions: const CookingConditions(spice: SpicePreference.mild)),
          isNot(base));
      expect(
          key(cfg: const AiConfig(apiKey: 'k', baseUrl: 'https://ai.example/v1', model: 'm2')),
          isNot(base));
    });

    test('the key never contains the API key', () {
      const secret = AiConfig(
          apiKey: 'sk-secret-123456', baseUrl: 'https://ai.example/v1', model: 'm');
      expect(key(cfg: secret), isNot(contains('sk-secret')));
    });
  });
}
