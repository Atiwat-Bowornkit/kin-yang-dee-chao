import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';

/// ป้ายข้อมูลเล็ก ๆ: ไอคอน + ข้อความ (เวลา/ความยาก/แคลอรี)
class InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool filled;

  const InfoPill({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? c.withValues(alpha: 0.12) : p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium!.copyWith(
                color: filled ? c : p.ink,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ข้อความเวลาแบบสั้น เช่น "15 นาที", "1 ชม. 30 นาที"
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes นาที';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h ชม.' : '$h ชม. $m นาที';
}

/// เวลาของสูตร: สูตร AI เป็นค่าประมาณ ส่วนสูตรที่ไม่ทราบเวลาแสดงว่าไม่ทราบ
String recipeTimeLabel(Recipe r) {
  if (!r.timeKnown) return 'ไม่ทราบเวลา';
  final m = formatMinutes(r.totalMinutes);
  return r.isAiGenerated ? '≈ $m' : m;
}

/// แคลอรีเป็นค่าประมาณเสมอ (ไม่ได้คำนวณจากฐานข้อมูลโภชนาการ)
String? kcalLabel(Recipe r) =>
    r.kcalPerServing == null ? null : '≈ ${r.kcalPerServing} kcal';

IconData difficultyIcon(Difficulty d) => switch (d) {
  Difficulty.easy => Icons.sentiment_satisfied_alt_outlined,
  Difficulty.medium => Icons.local_fire_department_outlined,
  Difficulty.hard => Icons.whatshot_outlined,
};

/// แถวป้ายข้อมูลมาตรฐานของสูตร (เวลา · ความยาก · kcal)
class RecipeInfoRow extends StatelessWidget {
  final Recipe recipe;
  final bool showKcal;

  const RecipeInfoRow({super.key, required this.recipe, this.showKcal = true});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.xs + 2,
      runSpacing: Space.xs + 2,
      children: [
        InfoPill(icon: Icons.schedule, label: recipeTimeLabel(recipe)),
        InfoPill(
          icon: difficultyIcon(recipe.difficulty),
          label: recipe.difficulty.label,
        ),
        if (showKcal && recipe.kcalPerServing != null)
          InfoPill(icon: Icons.bolt_outlined, label: kcalLabel(recipe)!),
      ],
    );
  }
}
