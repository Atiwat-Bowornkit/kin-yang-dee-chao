import 'package:flutter/material.dart';

import '../data/recipe_repository.dart';
import '../data/recommendation.dart';
import '../models/recipe.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'ai_badge.dart';
import 'favorite_button.dart';
import 'info_pill.dart';
import 'recipe_cover.dart';

/// tag ของ Hero ภาพปก (การ์ด → หน้ารายละเอียด)
Object recipeHeroTag(Recipe r, [String scope = '']) =>
    'cover:$scope:${r.favoriteKey}';

/// การ์ดเมนูแนวนอน: ภาพปก | ชื่อ + ข้อมูล + สถานะวัตถุดิบ | หัวใจ
class RecipeCard extends StatelessWidget {
  final RecipeMatch match;
  final VoidCallback onTap;

  /// เหตุผลการแนะนำ (มีเมื่อการ์ดมาจากผลการจับคู่กับวัตถุดิบ)
  final RecommendationExplanation? explanation;

  /// แยก Hero ของรายการเดียวกันที่อยู่หลายที่บนจอ
  final String heroScope;

  const RecipeCard({
    super.key,
    required this.match,
    required this.onTap,
    this.explanation,
    this.heroScope = '',
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final recipe = match.recipe;
    final checks = explanation?.checks ?? const <ConditionCheck>[];

    final String status;
    if (match.browsing) {
      status = recipe.description.isNotEmpty
          ? recipe.description
          : 'ส่วนผสม ${recipe.ingredients.length} อย่าง';
    } else if (match.need.isEmpty) {
      status = match.pantryNeed.isEmpty
          ? 'มีวัตถุดิบครบแล้ว ทำได้เลย!'
          : 'มีวัตถุดิบหลักครบ · เตรียมเพิ่ม ${[for (final i in match.pantryNeed) i.name].join(', ')}';
    } else {
      status = 'ขาด ${match.needNames.join(', ')}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: p.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RecipeCover(
                  recipe: recipe,
                  width: 92,
                  height: 92,
                  radius: Radii.md,
                  heroTag: recipeHeroTag(recipe, heroScope),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (recipe.isAiGenerated) ...[
                        const AiBadge(),
                        const SizedBox(height: Space.xs),
                      ],
                      Text(recipe.nameTh, style: t.titleMedium),
                      const SizedBox(height: Space.xs),
                      RecipeInfoRow(recipe: recipe, showKcal: false),
                      const SizedBox(height: Space.sm),
                      if (!match.browsing) ...[
                        _CoverageBar(match: match),
                        const SizedBox(height: Space.xs),
                      ],
                      // ข้อมูลที่ใช้ตัดสินใจเลือกเมนู: แสดงครบ ไม่ตัดด้วย …
                      Text(
                        status,
                        maxLines: match.browsing ? 2 : null,
                        overflow: match.browsing ? TextOverflow.ellipsis : null,
                        style: t.bodySmall!.copyWith(
                          color: !match.browsing && match.need.isEmpty
                              ? p.success
                              : p.muted,
                        ),
                      ),
                      if (checks.isNotEmpty) ...[
                        const SizedBox(height: Space.xs),
                        ConditionChips(checks: checks),
                      ],
                    ],
                  ),
                ),
                FavoriteButton(recipe: recipe),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// แถบแสดงว่ามีวัตถุดิบกี่อย่างจากที่ต้องใช้
class _CoverageBar extends StatelessWidget {
  final RecipeMatch match;

  const _CoverageBar({required this.match});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final haveCore = match.haveCore.length;
    final total = match.coreTotal;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: match.coverage,
              minHeight: 5,
              color: match.need.isEmpty ? p.success : p.accent,
              backgroundColor: p.line,
            ),
          ),
        ),
        const SizedBox(width: Space.sm),
        Semantics(
          label: total == 0
              ? 'ไม่มีวัตถุดิบหลักที่ต้องใช้'
              : 'มีวัตถุดิบหลัก $haveCore จาก $total อย่าง',
          excludeSemantics: true,
          child: Text(
            total == 0 ? 'ไม่ต้องใช้วัตถุดิบหลัก' : 'มี $haveCore/$total',
            style: context.text.labelSmall!.copyWith(color: p.muted),
          ),
        ),
      ],
    );
  }
}

/// ป้ายผลตรวจเงื่อนไข: ผ่านทั้งหมด → ป้ายเดียว, ไม่ผ่าน/ไม่ทราบ → แสดงทีละข้อ
class ConditionChips extends StatelessWidget {
  final List<ConditionCheck> checks;

  const ConditionChips({super.key, required this.checks});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text.labelMedium!;
    Widget chip(IconData icon, String text, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(text, style: t.copyWith(color: color)),
        ),
      ],
    );
    final problems = [
      for (final c in checks)
        if (c.status != CheckStatus.pass) c,
    ];
    if (problems.isEmpty) {
      return chip(Icons.check_circle_outline, 'ตรงเงื่อนไขที่เลือก', p.success);
    }
    return Wrap(
      spacing: Space.md,
      runSpacing: 2,
      children: [
        for (final c in problems)
          c.status == CheckStatus.fail
              ? chip(Icons.cancel_outlined, '${c.name}: ${c.detail}', p.error)
              : chip(Icons.help_outline, '${c.name}: ${c.detail}', p.muted),
      ],
    );
  }
}

/// การ์ดเมนูแนวตั้งขนาดเล็ก (แถวเลื่อนแนวนอน เช่น "เมนูแนะนำวันนี้")
class RecipeTile extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final double width;
  final String heroScope;

  const RecipeTile({
    super.key,
    required this.recipe,
    required this.onTap,
    this.width = 150,
    this.heroScope = 'tile',
  });

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Semantics(
      button: true,
      label: 'เปิดสูตร ${recipe.nameTh}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecipeCover(
                recipe: recipe,
                width: width,
                height: width * 0.78,
                radius: Radii.lg,
                heroTag: recipeHeroTag(recipe, heroScope),
              ),
              const SizedBox(height: Space.sm),
              Text(
                recipe.nameTh,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.titleSmall,
              ),
              Text(
                '${recipeTimeLabel(recipe)} · ${recipe.difficulty.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
