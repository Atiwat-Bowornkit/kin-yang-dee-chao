import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/formatters.dart';
import '../../data/recipe_repository.dart';
import '../../data/recommendation.dart';
import '../../models/ai_trace.dart';
import '../../models/ingredient.dart';
import '../../models/scan_record.dart';
import '../../services/api_service.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/content_width.dart';
import '../../widgets/scan_thumb.dart';
import '../../widgets/section_heading.dart';
import '../review/ingredient_review_screen.dart';

/// สรุปการวิเคราะห์: ผล AI เดิม → สิ่งที่ผู้ใช้ยืนยัน → การเปลี่ยนแปลง → เมนูและเหตุผล
/// รายละเอียดทางเทคนิค (trace) แสดงเมื่อเปิดโหมดสาธิตในหน้าตั้งค่า
class AnalysisSummaryScreen extends StatelessWidget {
  final String recordId;

  const AnalysisSummaryScreen({super.key, required this.recordId});

  static Route<void> route(String id) =>
      MaterialPageRoute(builder: (_) => AnalysisSummaryScreen(recordId: id));

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final r = scope.history.byId(recordId);
    final demo = scope.settings.demoMode;
    return Scaffold(
      appBar: AppBar(title: const Text('สรุปการวิเคราะห์')),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: r == null
              ? const Center(child: Text('ไม่พบรายการนี้แล้ว'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.screen,
                    Space.xs,
                    Space.screen,
                    Space.xxxl,
                  ),
                  children: [
                    _Header(record: r),
                    const SizedBox(height: Space.xl),
                    _BeforeAfter(record: r),
                    const SizedBox(height: Space.xl),
                    _Recipes(record: r),
                    const SizedBox(height: Space.xl),
                    if (demo) ...[
                      const _FlowDiagram(),
                      const SizedBox(height: Space.xl),
                      _Traces(record: r),
                    ] else
                      Text(
                        'เปิด "โหมดสาธิต" ในหน้าตั้งค่าเพื่อดูรายละเอียดทางเทคนิคของการเรียก AI',
                        style: context.text.bodySmall,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ScanRecord record;

  const _Header({required this.record});

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final r = record;
    return Row(
      children: [
        ScanThumb(record: r, width: 88, height: 88),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.manual ? 'เลือกวัตถุดิบเอง' : 'สแกนจากรูป',
                style: t.titleMedium,
              ),
              Text(formatRelativeThai(r.createdAt), style: t.bodySmall),
              const SizedBox(height: Space.xs),
              Text('สถานะ: ${r.status.label}', style: t.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _BeforeAfter extends StatelessWidget {
  final ScanRecord record;

  const _BeforeAfter({required this.record});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final r = record;
    final changes = r.changes;
    String names(List<DetectedIngredient> l) =>
        l.isEmpty ? '–' : [for (final i in l) i.nameTh].join(', ');

    Widget block(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.labelLarge),
          const SizedBox(height: 2),
          Text(body, style: t.bodyMedium),
        ],
      ),
    );

    return Panel(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ก่อน–หลังการตรวจ', style: t.titleSmall),
          const SizedBox(height: Space.md),
          if (!r.manual)
            block(
              'AI ตรวจพบ',
              r.status == ScanStatus.legacy
                  ? '${names(r.detected)}\n(ข้อมูลเวอร์ชันเก่า: ไม่ได้เก็บผล AI แยกจากรายการที่แก้)'
                  : '${names(r.detected)}'
                        '${r.aiReportedCount != null && r.aiReportedCount! > r.detected.length ? '\nAI ตอบมา ${r.aiReportedCount} รายการ แสดงได้ไม่เกินขีดจำกัด' : ''}',
            ),
          block(
            r.isConfirmed ? 'ผู้ใช้ยืนยัน' : 'รายการปัจจุบัน (ยังไม่ยืนยัน)',
            names(r.ingredients),
          ),
          if (!r.manual) ...[
            block('เพิ่มเอง', names(changes.added)),
            block('ลบออก', names(changes.removed)),
            block(
              'แก้ชื่อ',
              changes.renamed.isEmpty
                  ? '–'
                  : [
                      for (final x in changes.renamed) '${x.from} → ${x.to}',
                    ].join(', '),
            ),
          ],
          block(
            'ของในครัวที่ยืนยันว่ามี (ผู้ใช้เลือก ไม่ได้มาจาก AI)',
            r.kitchen.isEmpty ? '–' : kitchenNames(r.kitchen),
          ),
          block('เงื่อนไข', r.conditions.summary.join(' · ')),
          if (!r.isConfirmed)
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).push(IngredientReviewScreen.route(r.id)),
              child: const Text('ตรวจและยืนยันวัตถุดิบ'),
            ),
          if (r.confirmedAt != null)
            Text(
              'ยืนยันแล้ว · ${formatRelativeThai(r.confirmedAt!)}',
              style: t.bodySmall!.copyWith(color: p.muted),
            ),
        ],
      ),
    );
  }
}

class _Recipes extends StatelessWidget {
  final ScanRecord record;

  const _Recipes({required this.record});

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final scope = AppScope.of(context);
    final r = record;
    if (!r.isConfirmed) {
      return Text(
        'ยังไม่มีเมนู เพราะยังไม่ได้ยืนยันวัตถุดิบ',
        style: t.bodyMedium,
      );
    }
    final kitchen = effectiveKitchen(r, scope.settings.kitchen);
    final curated = rankRecommendations(
      const RecipeRepository().matchRecipes(r.ingredients, kitchen: kitchen),
      r.conditions,
    );
    final key = ApiService.suggestionInputKey(
      owned: r.ingredients,
      kitchen: kitchen,
      conditions: r.conditions,
      config: scope.ai.config,
    );
    final cache = r.ai;
    final fresh = cache != null && cache.inputKey == key;
    final ai = cache == null
        ? const <RecommendationExplanation>[]
        : rankRecommendations(
            [
              for (final x in cache.recipes)
                matchAiRecipe(x, r.ingredients, kitchen: kitchen),
            ],
            r.conditions,
            source: fresh ? RecipeSource.aiSaved : RecipeSource.aiStale,
          );

    Widget row(RecommendationExplanation e) {
      final fails = [
        for (final c in e.checks)
          if (c.status == CheckStatus.fail) c.name,
      ];
      final unknown = [
        for (final c in e.checks)
          if (c.status == CheckStatus.unknown) c.name,
      ];
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.recipe.nameTh, style: t.titleSmall),
            Text(
              [
                e.coverageLabel,
                if (e.match.toPrepare.isNotEmpty)
                  'ต้องเตรียม ${[for (final i in e.match.toPrepare) i.name].join(', ')}',
                if (fails.isNotEmpty) 'ไม่ผ่าน: ${fails.join(', ')}',
                if (unknown.isNotEmpty) 'ตรวจไม่ได้: ${unknown.join(', ')}',
                if (fails.isEmpty && unknown.isEmpty && e.checks.isNotEmpty)
                  'ตรงเงื่อนไข',
                e.source.label,
              ].join(' · '),
              style: t.bodySmall,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          'เมนูที่ผูกกับผลนี้',
          trailing: '${curated.length + ai.length} เมนู',
        ),
        Text(
          'ลำดับ: ผ่านเงื่อนไขก่อน → มีวัตถุดิบหลักครบกว่า → ขาดของสำคัญน้อยกว่า → ตรวจไม่ได้น้อยกว่า → ใช้เวลาน้อยกว่า',
          style: t.bodySmall,
        ),
        const SizedBox(height: Space.md),
        if (curated.isEmpty && ai.isEmpty)
          Text('ยังไม่มีเมนูที่ตรงกับวัตถุดิบนี้', style: t.bodyMedium),
        for (final e in curated.take(8)) row(e),
        if (curated.length > 8)
          Text(
            'และอีก ${curated.length - 8} เมนูจากสูตรในแอป',
            style: t.bodySmall,
          ),
        if (ai.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          for (final e in ai) row(e),
        ],
      ],
    );
  }
}

/// แผนผัง: ส่วนที่ AI ทำ เทียบกับตรรกะของแอป
class _FlowDiagram extends StatelessWidget {
  const _FlowDiagram();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    const steps = [
      ('AI', 'ระบุวัตถุดิบจากรูป (โมเดลของผู้ให้บริการผ่าน API)'),
      ('แอป', 'ตรวจรูปแบบ JSON · จับคู่ชื่อกับฐานข้อมูล · จำกัดจำนวน'),
      ('ผู้ใช้', 'ตรวจ แก้ชื่อ ลบ เพิ่ม และเลือกของในครัว แล้วยืนยัน'),
      ('แอป', 'จับคู่กับสูตรในแอป · ตรวจเงื่อนไข · จัดอันดับ · อธิบายเหตุผล'),
      ('AI', 'คิดเมนูเพิ่มจากรายการที่ยืนยัน + เงื่อนไข (เมื่อผู้ใช้กดขอ)'),
      (
        'แอป',
        'ตรวจสูตรที่ได้ · ตัดสูตรที่ไม่ครบ · ตรวจเงื่อนไขซ้ำ · บันทึกพร้อมคีย์ของ input',
      ),
    ];
    return Panel(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ขั้นตอนการทำงาน', style: t.titleSmall),
          const SizedBox(height: Space.md),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: steps[i].$1 == 'AI'
                          ? p.goldSoft
                          : steps[i].$1 == 'ผู้ใช้'
                          ? p.successSoft
                          : p.accentSoft,
                      borderRadius: BorderRadius.circular(Radii.xs),
                    ),
                    child: Text(
                      steps[i].$1,
                      style: t.labelMedium!.copyWith(color: p.ink),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      '${i + 1}. ${steps[i].$2}',
                      style: t.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'แอปไม่ได้ฝึกหรือปรับแต่งโมเดลเอง และไม่ได้เรียนรู้จากการแก้ไขของผู้ใช้',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Traces extends StatelessWidget {
  final ScanRecord record;

  const _Traces({required this.record});

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final traces = record.traces.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          'บันทึกการเรียก AI (โหมดสาธิต)',
          trailing: '${traces.length} ครั้ง',
        ),
        Text(
          'ไม่แสดง API key, header หรือ path ของไฟล์ในเครื่อง',
          style: t.bodySmall,
        ),
        const SizedBox(height: Space.md),
        if (traces.isEmpty)
          Text(
            record.manual
                ? 'รายการนี้เลือกวัตถุดิบเอง ยังไม่มีการเรียก AI'
                : 'ไม่มีบันทึก (ข้อมูลเวอร์ชันเก่า หรือยังไม่ได้ขอเมนูจาก AI)',
            style: t.bodyMedium,
          ),
        for (final tr in traces) _TraceCard(trace: tr),
      ],
    );
  }
}

class _TraceCard extends StatelessWidget {
  final AiTrace trace;

  const _TraceCard({required this.trace});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final tr = trace;
    final rows = <(String, String)>[
      ('request id', tr.requestId),
      ('เวลาที่วัดได้', '${(tr.durationMs / 1000).toStringAsFixed(1)} วินาที'),
      ('endpoint', tr.endpoint),
      ('model', tr.model),
      ('prompt', tr.promptVersion),
      ('input', tr.inputSummary),
      ('HTTP', tr.httpStatus?.toString() ?? '–'),
      ('finish_reason', tr.finishReason ?? '–'),
      ('parser/validation', tr.parserStatus),
      if (tr.errorType != null) ('error', tr.errorType!),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Panel(
        padding: const EdgeInsets.all(Space.md),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(tr.kind.label, style: t.titleSmall),
            subtitle: Text(
              '${formatRelativeThai(tr.startedAt)} · ${tr.parserStatus} · ${(tr.durationMs / 1000).toStringAsFixed(1)} วิ',
              style: t.bodySmall,
            ),
            children: [
              for (final (k, v) in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(k, style: t.labelMedium),
                      ),
                      Expanded(
                        child: SelectableText(
                          v,
                          style: t.bodySmall!.copyWith(color: p.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              if (tr.notes.isNotEmpty) ...[
                const SizedBox(height: Space.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ผลตรวจ: ${tr.notes.join(' · ')}',
                    style: t.bodySmall,
                  ),
                ),
              ],
              if (tr.responseExcerpt.isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Space.sm),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: SelectableText(
                    tr.responseExcerpt,
                    style: t.bodySmall!.copyWith(
                      fontFamily: 'monospace',
                      color: p.ink,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
