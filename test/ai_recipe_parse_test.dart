import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/data/recommendation.dart';
import 'package:kinyangdeechao/models/cooking_conditions.dart';
import 'package:kinyangdeechao/models/recipe.dart';
import 'package:kinyangdeechao/services/api_service.dart';

/// parser สูตร AI → evaluateConditions: ข้อมูลไม่ครบต้องเป็น "ไม่ทราบ" ไม่ใช่ "ผ่าน"
void main() {
  Map<String, Object?> base([Map<String, Object?> extra = const {}]) => {
    'name_th': 'ข้าวไข่เจียว',
    'ingredients': ['ไข่ไก่', 'ข้าวสวย'],
    'steps': ['ตีไข่', 'ทอดไข่'],
    ...extra,
  };

  group('time: partial / invalid is never a known total', () {
    final cases = <String, Map<String, Object?>>{
      'only cook': {'cook_minutes': 5},
      'only prep': {'prep_minutes': 5},
      'cook is a string': {'prep_minutes': 5, 'cook_minutes': '5'},
      'cook is bool': {'prep_minutes': 5, 'cook_minutes': true},
      'cook out of range': {'prep_minutes': 5, 'cook_minutes': 9999},
      'prep negative': {'prep_minutes': -3, 'cook_minutes': 5},
      'prep -0.4 (rounds to 0)': {'prep_minutes': -0.4, 'cook_minutes': 5},
      'cook -0.4 (rounds to 0)': {'prep_minutes': 5, 'cook_minutes': -0.4},
      'prep 240.4 (over max before rounding)': {
        'prep_minutes': 240.4,
        'cook_minutes': 5,
      },
      'cook NaN': {'prep_minutes': 5, 'cook_minutes': double.nan},
      'both zero': {'prep_minutes': 0, 'cook_minutes': 0},
    };
    for (final c in cases.entries) {
      test(c.key, () {
        final r = ApiService.parseAiRecipe(base(c.value)).recipe!;
        expect(r.timeKnown, isFalse);
        final checks = evaluateConditions(
          r,
          const CookingConditions(maxMinutes: 15),
        );
        expect(
          checks.single.status,
          CheckStatus.unknown,
          reason: 'ต้องไม่ผ่านเงื่อนไขเวลาด้วยเวลาที่ไม่ครบ',
        );
      });
    }

    test('both valid → known and judged', () {
      final r = ApiService.parseAiRecipe(
        base({'prep_minutes': 5, 'cook_minutes': 10}),
      ).recipe!;
      expect(r.timeKnown, isTrue);
      expect(r.totalMinutes, 15);
      expect(
        evaluateConditions(
          r,
          const CookingConditions(maxMinutes: 15),
        ).single.status,
        CheckStatus.pass,
      );
      expect(
        evaluateConditions(
          r,
          const CookingConditions(maxMinutes: 10),
        ).single.status,
        CheckStatus.fail,
      );
    });
  });

  group('equipment', () {
    const noStove = CookingConditions(equipment: {});

    test('unparseable value → unknown, not a complete-looking set', () {
      final r = ApiService.parseAiRecipe(
        base({
          'equipment': ['pan', 'rocket'],
        }),
      ).recipe!;
      expect(r.equipment, isNull);
      expect(evaluateConditions(r, noStove).single.status, CheckStatus.unknown);
    });

    test('non-list / missing → unknown', () {
      for (final v in <Object?>['pan', 5, null]) {
        final r = ApiService.parseAiRecipe(base({'equipment': v})).recipe!;
        expect(r.equipment, isNull, reason: '$v');
      }
      expect(ApiService.parseAiRecipe(base()).recipe!.equipment, isNull);
    });

    test('non-string element → unknown', () {
      final r = ApiService.parseAiRecipe(
        base({
          'equipment': ['pan', 3],
        }),
      ).recipe!;
      expect(r.equipment, isNull);
    });

    test('genuine [] means no equipment and passes a no-stove check', () {
      final r = ApiService.parseAiRecipe(base({'equipment': []})).recipe!;
      expect(r.equipment, isEmpty);
      expect(evaluateConditions(r, noStove).single.status, CheckStatus.pass);
    });

    test('known equipment is checked against what the user has', () {
      final r = ApiService.parseAiRecipe(
        base({
          'equipment': ['pan', 'pot'],
        }),
      ).recipe!;
      expect(r.equipment, {Equipment.pan, Equipment.pot});
      expect(evaluateConditions(r, noStove).single.status, CheckStatus.fail);
    });

    test('persisted recipe with unreadable equipment stays unknown', () {
      final json = ApiService.parseAiRecipe(
        base({'equipment': []}),
      ).recipe!.toJson();
      json['equipment'] = ['pan', 'rocket'];
      expect(recipeFromJson(json).equipment, isNull);
    });
  });

  group('over-limit content is rejected, never truncated', () {
    test('long step is rejected with a reason', () {
      final long = 'ผัด' * ApiService.maxAiStepChars;
      final p = ApiService.parseAiRecipe(
        base({
          'steps': ['ตีไข่', long],
        }),
      );
      expect(p.recipe, isNull);
      expect(p.problem, contains('ขั้นตอนยาวเกิน'));
    });

    test('step at the limit is kept whole', () {
      final s = 'ก' * ApiService.maxAiStepChars;
      final r = ApiService.parseAiRecipe(
        base({
          'steps': ['ตีไข่', s],
        }),
      ).recipe!;
      expect(r.steps.last, s);
    });

    test('too many steps → rejected, none dropped', () {
      final p = ApiService.parseAiRecipe(
        base({
          'steps': [
            for (var i = 0; i < ApiService.maxAiSteps + 1; i++) 'ขั้น $i',
          ],
        }),
      );
      expect(p.recipe, isNull);
      expect(p.problem, contains('ขั้นตอนเกิน'));
    });

    test('13 steps (old cap was 12) are all kept', () {
      final r = ApiService.parseAiRecipe(
        base({
          'steps': [for (var i = 0; i < 13; i++) 'ขั้น $i'],
        }),
      ).recipe!;
      expect(r.steps, hasLength(13));
    });

    test('too many ingredients → rejected', () {
      final p = ApiService.parseAiRecipe(
        base({
          'ingredients': [
            for (var i = 0; i < ApiService.maxAiIngredients + 1; i++) 'ของ$i',
          ],
        }),
      );
      expect(p.recipe, isNull);
      expect(p.problem, contains('ส่วนผสมเกิน'));
    });

    test('16 ingredients (old cap was 15) are all kept', () {
      final r = ApiService.parseAiRecipe(
        base({
          'ingredients': [for (var i = 0; i < 16; i++) 'ของ$i'],
        }),
      ).recipe!;
      expect(r.ingredients, hasLength(16));
    });

    test('malformed step entry rejects instead of silently vanishing', () {
      final p = ApiService.parseAiRecipe(
        base({
          'steps': ['ตีไข่', 5, 'ทอดไข่'],
        }),
      );
      expect(p.recipe, isNull);
      expect(p.problem, contains('ขั้นตอน'));
    });

    test('unreadable amount keeps the ingredient with unknown amount', () {
      final r = ApiService.parseAiRecipe(
        base({
          'ingredients': [
            'ไข่ไก่',
            {'name': 'ข้าวสวย', 'amount': 'หนึ่งถ้วย'},
          ],
        }),
      ).recipe!;
      expect(r.ingredients, hasLength(2));
      expect(r.ingredients.last.amount, isNull);
    });

    test('over-limit description is omitted, not cut mid-sentence', () {
      final r = ApiService.parseAiRecipe(
        base({'description': 'ก' * (ApiService.maxAiDescription + 1)}),
      ).recipe!;
      expect(r.description, isEmpty);
    });
  });
}
