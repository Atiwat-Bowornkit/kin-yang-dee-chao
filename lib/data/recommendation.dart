import '../models/cooking_conditions.dart';
import '../models/recipe.dart';
import 'recipe_repository.dart';

enum CheckStatus { pass, fail, unknown }

/// ผลตรวจเงื่อนไขหนึ่งข้อของสูตร (คำนวณจากข้อมูลสูตรจริง ไม่ใช่ข้อความจาก AI)
class ConditionCheck {
  final String name;
  final CheckStatus status;
  final String detail;

  const ConditionCheck(this.name, this.status, this.detail);
}

/// แหล่งที่มาของสูตรที่แนะนำ
enum RecipeSource {
  curated('สูตรในแอป'),
  ai('สูตรจาก AI'),
  aiSaved('สูตรจาก AI (ผลที่บันทึกไว้)'),
  aiStale('สูตรจาก AI (ผลเก่า ก่อนแก้ไขวัตถุดิบ/เงื่อนไข)');

  final String label;
  const RecipeSource(this.label);
}

/// ตรวจเงื่อนไขของผู้ใช้กับสูตร: เวลา อุปกรณ์ ความเผ็ด
/// เงื่อนไขที่ผู้ใช้ไม่ได้กำหนดจะไม่ถูกตรวจ (ไม่แสดงว่า "ผ่าน")
List<ConditionCheck> evaluateConditions(Recipe r, CookingConditions c) {
  final out = <ConditionCheck>[];

  final max = c.maxMinutes;
  if (max != null) {
    if (!r.timeKnown) {
      out.add(
        const ConditionCheck('เวลา', CheckStatus.unknown, 'ไม่ทราบเวลาที่ใช้'),
      );
    } else {
      final est = r.isAiGenerated ? ' (AI ประมาณ)' : '';
      out.add(
        r.totalMinutes <= max
            ? ConditionCheck(
                'เวลา',
                CheckStatus.pass,
                'ประมาณ ${r.totalMinutes} นาที$est ไม่เกิน $max นาที',
              )
            : ConditionCheck(
                'เวลา',
                CheckStatus.fail,
                'ประมาณ ${r.totalMinutes} นาที$est เกิน $max นาที',
              ),
      );
    }
  }

  final have = c.equipment;
  if (have != null) {
    final need = r.equipment;
    if (need == null) {
      out.add(
        const ConditionCheck(
          'อุปกรณ์',
          CheckStatus.unknown,
          'สูตรไม่ได้ระบุอุปกรณ์',
        ),
      );
    } else {
      final missing = [
        for (final e in Equipment.values)
          if (need.contains(e) && !have.contains(e)) e.label,
      ];
      out.add(
        missing.isEmpty
            ? ConditionCheck(
                'อุปกรณ์',
                CheckStatus.pass,
                need.isEmpty
                    ? 'ไม่ต้องใช้เตา/อุปกรณ์ให้ความร้อน'
                    : 'มีอุปกรณ์ที่ต้องใช้ครบ',
              )
            : ConditionCheck(
                'อุปกรณ์',
                CheckStatus.fail,
                'ต้องใช้ ${missing.join(', ')}',
              ),
      );
    }
  }

  if (c.spice == SpicePreference.mild) {
    final spicy = r.isSpicy;
    out.add(switch (spicy) {
      null => const ConditionCheck(
        'ความเผ็ด',
        CheckStatus.unknown,
        'ไม่ทราบว่าเผ็ดหรือไม่',
      ),
      true => const ConditionCheck(
        'ความเผ็ด',
        CheckStatus.fail,
        'เป็นเมนูเผ็ด',
      ),
      false => const ConditionCheck('ความเผ็ด', CheckStatus.pass, 'ไม่เผ็ด'),
    });
  }
  return out;
}

/// เหตุผลที่แนะนำเมนู — ทุกค่าคำนวณจาก [RecipeMatch] และเงื่อนไขจริง
class RecommendationExplanation {
  final RecipeMatch match;
  final List<ConditionCheck> checks;
  final RecipeSource source;

  const RecommendationExplanation({
    required this.match,
    required this.checks,
    required this.source,
  });

  factory RecommendationExplanation.of(
    RecipeMatch match,
    CookingConditions conditions, {
    RecipeSource? source,
  }) => RecommendationExplanation(
    match: match,
    checks: evaluateConditions(match.recipe, conditions),
    source:
        source ??
        (match.recipe.isAiGenerated ? RecipeSource.ai : RecipeSource.curated),
  );

  Recipe get recipe => match.recipe;
  int get coreHave => match.haveCore.length;
  int get coreTotal => match.coreTotal;
  int get failCount => checks.where((c) => c.status == CheckStatus.fail).length;
  int get unknownCount =>
      checks.where((c) => c.status == CheckStatus.unknown).length;
  bool get passesAll => failCount == 0;

  /// ข้อความสัดส่วนความครบของวัตถุดิบ (ไม่ใช่ความแม่นยำ/ความมั่นใจของ AI)
  String get coverageLabel => coreTotal == 0
      ? 'สูตรนี้ไม่มีวัตถุดิบหลักที่ต้องใช้'
      : 'มีวัตถุดิบหลัก $coreHave/$coreTotal อย่าง';
}

/// จัดอันดับแบบคงที่และอธิบายได้:
/// 1) ไม่ผ่านเงื่อนไขน้อยข้อก่อน 2) ความครบของวัตถุดิบหลักมากก่อน
/// 3) ของสำคัญที่ขาดน้อยก่อน 4) ข้อที่ตรวจไม่ได้น้อยก่อน
/// 5) ใช้เวลาน้อยก่อน (สูตรที่ไม่ทราบเวลาอยู่หลัง) 6) id เพื่อให้ลำดับคงที่
List<RecommendationExplanation> rankRecommendations(
  Iterable<RecipeMatch> matches,
  CookingConditions conditions, {
  RecipeSource? source,
}) {
  final list = [
    for (final m in matches)
      RecommendationExplanation.of(m, conditions, source: source),
  ];
  list.sort(compareRecommendations);
  return list;
}

int compareRecommendations(
  RecommendationExplanation a,
  RecommendationExplanation b,
) {
  var c = a.failCount.compareTo(b.failCount);
  if (c != 0) return c;
  c = b.match.coverage.compareTo(a.match.coverage);
  if (c != 0) return c;
  c = a.match.need.length.compareTo(b.match.need.length);
  if (c != 0) return c;
  c = a.unknownCount.compareTo(b.unknownCount);
  if (c != 0) return c;
  int minutes(Recipe r) => r.timeKnown ? r.totalMinutes : 1 << 20;
  c = minutes(a.recipe).compareTo(minutes(b.recipe));
  if (c != 0) return c;
  return a.recipe.id.compareTo(b.recipe.id);
}
