import 'package:flutter/material.dart';

import '../data/recommendation.dart';
import '../models/recipe.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'section_heading.dart';

/// "ทำไมแนะนำเมนูนี้" — แสดงข้อมูลที่คำนวณจริงจากวัตถุดิบที่ยืนยันและเงื่อนไข
/// (สัดส่วน x/y คือความครบของวัตถุดิบ ไม่ใช่ความแม่นยำหรือความมั่นใจของ AI)
class ExplanationPanel extends StatelessWidget {
  final RecommendationExplanation explanation;

  const ExplanationPanel({super.key, required this.explanation});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final e = explanation;
    final m = e.match;
    String names(List<RecipeIngredient> list) =>
        list.isEmpty ? '–' : [for (final i in list) i.name].join(', ');

    Widget line(IconData icon, Color color, String label, String value) =>
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$label  ', style: t.labelLarge),
                      TextSpan(text: value, style: t.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

    final complete = m.need.isEmpty;
    return Panel(
      color: Color.alphaBlend(
        (complete ? p.success : p.accent).withValues(alpha: 0.07),
        p.surface,
      ),
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ทำไมแนะนำเมนูนี้', style: t.titleSmall),
          const SizedBox(height: 2),
          Text(
            e.coverageLabel,
            style: t.titleMedium!.copyWith(
              color: complete ? p.success : p.accent,
            ),
          ),
          line(
            Icons.check_circle_outline,
            p.success,
            'มีแล้ว',
            names([
              for (final i in m.have)
                if (!i.isPantry) i,
            ]),
          ),
          line(
            Icons.shopping_basket_outlined,
            p.accent,
            'ต้องเตรียมเพิ่ม',
            names(m.toPrepare),
          ),
          if (m.optional.isNotEmpty)
            line(
              Icons.add_circle_outline,
              p.muted,
              'ของเสริม (ไม่มีก็ได้)',
              names(m.optional),
            ),
          line(
            Icons.kitchen_outlined,
            p.muted,
            'ของในครัวที่เลือกไว้ (ไม่นับเป็นของขาด)',
            names([
              ...m.staples,
              for (final i in m.have)
                if (i.isPantry) i,
            ]),
          ),
          if (e.checks.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Text('เงื่อนไขที่เลือก', style: t.labelLarge),
            for (final c in e.checks)
              line(
                switch (c.status) {
                  CheckStatus.pass => Icons.check,
                  CheckStatus.fail => Icons.close,
                  CheckStatus.unknown => Icons.help_outline,
                },
                switch (c.status) {
                  CheckStatus.pass => p.success,
                  CheckStatus.fail => p.error,
                  CheckStatus.unknown => p.muted,
                },
                switch (c.status) {
                  CheckStatus.pass => '${c.name} ผ่าน',
                  CheckStatus.fail => '${c.name} ไม่ผ่าน',
                  CheckStatus.unknown => '${c.name} ตรวจไม่ได้',
                },
                c.detail,
              ),
          ],
          const SizedBox(height: Space.md),
          Text('แหล่งสูตร: ${e.source.label}', style: t.bodySmall),
        ],
      ),
    );
  }
}
