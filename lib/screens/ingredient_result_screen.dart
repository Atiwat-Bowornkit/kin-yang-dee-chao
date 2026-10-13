import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/app_scope.dart';
import '../data/recipe_repository.dart';
import '../data/recommendation.dart';
import '../models/scan_record.dart';
import '../services/api_service.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/brand_loading.dart';
import '../widgets/conditions_sheet.dart';
import '../widgets/content_width.dart';
import '../widgets/fade_in.dart';
import '../widgets/ingredient_chip.dart';
import '../widgets/recipe_card.dart';
import '../widgets/section_heading.dart';
import 'recipe_detail_screen.dart';
import 'review/ingredient_review_screen.dart';
import 'settings/ai_settings_screen.dart';
import 'summary/analysis_summary_screen.dart';

/// ผลลัพธ์ของรายการที่ยืนยันแล้ว: วัตถุดิบ + เงื่อนไข → สูตรในแอป → สูตรจาก AI (เมื่อผู้ใช้ขอ)
/// รายการที่ยังไม่ยืนยัน (draft/legacy) จะไม่ถูกใช้หาเมนู และมีทางไปหน้าตรวจ
class IngredientResultScreen extends StatefulWidget {
  final String recordId;

  const IngredientResultScreen({super.key, required this.recordId});

  static Route<void> route(String recordId) => MaterialPageRoute(
    builder: (_) => IngredientResultScreen(recordId: recordId),
  );

  /// เปิดรายการจากประวัติ: ยังไม่ยืนยัน → หน้าตรวจ, ยืนยันแล้ว → หน้าผลลัพธ์
  static Route<void> routeForRecord(ScanRecord record) => record.isConfirmed
      ? route(record.id)
      : IngredientReviewScreen.route(record.id);

  @override
  State<IngredientResultScreen> createState() => _IngredientResultScreenState();
}

class _IngredientResultScreenState extends State<IngredientResultScreen> {
  static const _repo = RecipeRepository();

  bool _loadingAi = false;
  String? _aiError;
  CancelToken? _aiCancel;
  bool _showFailing = false;

  @override
  void dispose() {
    _aiCancel?.cancel();
    super.dispose();
  }

  ScanRecord? get _record =>
      AppScope.read(context).history.byId(widget.recordId);

  Set<String> _kitchen(ScanRecord r) =>
      effectiveKitchen(r, AppScope.read(context).settings.kitchen);

  String _inputKey(ScanRecord r) => ApiService.suggestionInputKey(
    owned: r.ingredients,
    kitchen: _kitchen(r),
    conditions: r.conditions,
    config: AppScope.read(context).ai.config,
  );

  /// ขอสูตรจาก AI เฉพาะเมื่อผู้ใช้กด (ไม่เรียกเองเมื่อเปิดหน้า/rebuild)
  Future<void> _loadAiRecipes() async {
    final r = _record;
    if (_loadingAi || r == null || !r.isConfirmed) return;
    final scope = AppScope.read(context);
    final token = CancelToken();
    _aiCancel?.cancel();
    _aiCancel = token;
    final key = _inputKey(r);
    setState(() {
      _loadingAi = true;
      _aiError = null;
    });
    try {
      final outcome = await scope.api.suggestRecipes(
        r.ingredients,
        kitchen: _kitchen(r),
        conditions: r.conditions,
        cancelToken: token,
      );
      // ผลของคำขอเก่าที่ถูกแทนแล้วต้องไม่เขียนทับ
      if (token.isCancelled || !identical(_aiCancel, token)) return;
      final saved = await scope.history.saveAiRecipes(
        r.id,
        AiRecipeCache(
          recipes: outcome.recipes,
          inputKey: key,
          createdAt: DateTime.now(),
          rejectedNotes: outcome.rejected,
        ),
        trace: outcome.trace,
      );
      if (!saved && mounted) {
        _snack('บันทึกสูตรจาก AI ลงเครื่องไม่สำเร็จ (ยังดูได้ในหน้านี้)');
      }
    } on RecognitionException catch (e) {
      if (e.trace != null) await scope.history.addTrace(r.id, e.trace!);
      if (mounted &&
          e.type != RecognitionErrorType.cancelled &&
          identical(_aiCancel, token)) {
        setState(() => _aiError = e.userMessage);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('suggestRecipes failed: ${e.runtimeType}');
      if (mounted && identical(_aiCancel, token)) {
        setState(
          () => _aiError = 'ไม่สามารถแนะนำเมนูได้ในขณะนี้\nกรุณาลองใหม่',
        );
      }
    } finally {
      if (mounted && identical(_aiCancel, token)) {
        setState(() => _loadingAi = false);
      }
    }
  }

  Future<void> _editConditions(ScanRecord r) async {
    final scope = AppScope.read(context);
    final next = await showConditionsSheet(context, r.conditions);
    if (next == null || next == r.conditions || !mounted) return;
    // เงื่อนไขเปลี่ยน → คำขอ AI ที่ค้างอยู่ใช้ input เก่า จึงยกเลิก
    _aiCancel?.cancel();
    setState(() {
      _loadingAi = false;
      _aiError = null;
    });
    final ok = await scope.history.updateConditions(r.id, next);
    await scope.settings.setConditions(next);
    if (!ok && mounted) _snack('บันทึกเงื่อนไขไม่สำเร็จ (ใช้ได้เฉพาะครั้งนี้)');
  }

  void _edit() {
    _aiCancel?.cancel();
    Navigator.of(context).push(IngredientReviewScreen.route(widget.recordId));
  }

  void _open(RecommendationExplanation e, String scope, int servings) {
    Navigator.of(context).push(
      RecipeDetailScreen.route(
        e.match,
        heroScope: scope,
        explanation: e,
        servings: servings,
      ),
    );
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final r = scope.history.byId(widget.recordId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('เมนูที่ทำได้'),
        actions: [
          if (r != null)
            IconButton(
              tooltip: 'สรุปการวิเคราะห์',
              onPressed: () => Navigator.of(
                context,
              ).push(AnalysisSummaryScreen.route(widget.recordId)),
              icon: const Icon(Icons.insights_outlined),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: r == null
              ? const Center(child: Text('ไม่พบรายการนี้แล้ว'))
              : !r.isConfirmed
              ? _buildNeedsConfirm(r)
              : _buildResults(r),
        ),
      ),
    );
  }

  Widget _buildNeedsConfirm(ScanRecord r) {
    final t = context.text;
    return ListView(
      padding: const EdgeInsets.all(Space.screen),
      children: [
        Panel(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ยังไม่ได้ยืนยันวัตถุดิบ', style: t.titleMedium),
              const SizedBox(height: Space.xs),
              Text(
                'แอปจะหาเมนูจากรายการที่คุณตรวจและยืนยันแล้วเท่านั้น',
                style: t.bodySmall,
              ),
              const SizedBox(height: Space.md),
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushReplacement(IngredientReviewScreen.route(r.id)),
                child: const Text('ตรวจและยืนยันวัตถุดิบ'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(ScanRecord r) {
    final p = context.palette;
    final t = context.text;
    final kitchen = _kitchen(r);
    final ranked = rankRecommendations(
      _repo.matchRecipes(r.ingredients, kitchen: kitchen),
      r.conditions,
    );
    final passing = [
      for (final e in ranked)
        if (e.passesAll) e,
    ];
    final failing = [
      for (final e in ranked)
        if (!e.passesAll) e,
    ];
    final shown = _showFailing ? ranked : passing;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.screen,
        Space.xs,
        Space.screen,
        Space.xxxl,
      ),
      children: [
        SectionHeading(
          'วัตถุดิบที่ยืนยันแล้ว',
          padding: const EdgeInsets.only(bottom: Space.sm),
          action: TextButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('แก้ไข'),
          ),
        ),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final i in r.ingredients) IngredientChip(ingredient: i),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          kitchen.isEmpty
              ? 'ของในครัว: ไม่ได้เลือก (เครื่องปรุงทุกอย่างจะแสดงว่าต้องเตรียม)'
              : 'ของในครัวที่เลือกไว้: ${kitchenNames(kitchen)}',
          style: t.bodySmall,
        ),
        const SizedBox(height: Space.lg),
        ConditionsBar(
          conditions: r.conditions,
          onEdit: () => _editConditions(r),
        ),
        const SizedBox(height: Space.xxl),
        SectionHeading('จากสูตรในแอป', trailing: '${passing.length} เมนู'),
        if (ranked.isEmpty)
          Panel(
            padding: const EdgeInsets.all(Space.lg),
            child: Text(
              'ยังไม่มีสูตรในแอปที่ใช้วัตถุดิบเหล่านี้\nลองเพิ่มวัตถุดิบ หรือให้ AI ช่วยคิดเมนูด้านล่าง',
              style: t.bodyMedium!.copyWith(color: p.muted),
            ),
          )
        else ...[
          if (passing.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Text(
                'ไม่มีสูตรในแอปที่ตรงทุกเงื่อนไข',
                style: t.bodyMedium!.copyWith(color: p.muted),
              ),
            ),
          for (var i = 0; i < shown.length; i++)
            FadeIn(
              index: i,
              child: RecipeCard(
                match: shown[i].match,
                explanation: shown[i],
                heroScope: 'result',
                onTap: () => _open(shown[i], 'result', r.conditions.servings),
              ),
            ),
          if (failing.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _showFailing = !_showFailing),
              icon: Icon(_showFailing ? Icons.expand_less : Icons.expand_more),
              label: Text(
                _showFailing
                    ? 'ซ่อนเมนูที่ไม่ตรงเงื่อนไข'
                    : 'ดูอีก ${failing.length} เมนูที่ไม่ตรงเงื่อนไข',
              ),
            ),
        ],
        const SizedBox(height: Space.xl),
        _buildAiSection(r, kitchen),
      ],
    );
  }

  Widget _buildAiSection(ScanRecord r, Set<String> kitchen) {
    final scope = AppScope.of(context);
    final p = context.palette;
    final t = context.text;
    final cache = r.ai;
    final fresh = cache != null && cache.inputKey == _inputKey(r);

    List<Widget> cards(RecipeSource source) {
      final ranked = rankRecommendations(
        [
          for (final x in cache!.recipes)
            matchAiRecipe(x, r.ingredients, kitchen: kitchen),
        ],
        r.conditions,
        source: source,
      );
      return [
        for (var i = 0; i < ranked.length; i++)
          FadeIn(
            index: i,
            child: RecipeCard(
              match: ranked[i].match,
              explanation: ranked[i],
              heroScope: 'ai',
              onTap: () => _open(ranked[i], 'ai', r.conditions.servings),
            ),
          ),
      ];
    }

    final heading = SectionHeading(
      'AI แนะนำเพิ่มเติม',
      aiBadge: true,
      trailing: fresh ? '${cache.recipes.length} เมนู' : null,
    );

    Widget requestButton(String label) => OutlinedButton.icon(
      onPressed: _loadAiRecipes,
      icon: Icon(_aiError != null ? Icons.refresh : Icons.auto_awesome),
      label: Text(label),
    );

    if (!scope.ai.hasKey && !fresh) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          Panel(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ตั้งค่าการเชื่อมต่อ AI เพื่อให้ช่วยคิดเมนูจากวัตถุดิบที่ไม่มีในสูตรของแอป สูตรในแอปด้านบนใช้ได้โดยไม่ต้องตั้งค่า',
                  style: t.bodyMedium!.copyWith(color: p.muted),
                ),
                const SizedBox(height: Space.md),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                  ),
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('ตั้งค่า AI'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        if (_loadingAi)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.xxl),
            child: BrandLoading(
              logoSize: 72,
              message: 'กำลังคิดเมนูให้...',
              hint: 'ส่งวัตถุดิบที่ยืนยันและเงื่อนไขให้ AI',
            ),
          )
        else ...[
          if (_aiError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Text(
                '$_aiError\nสูตรในแอปด้านบนยังใช้ได้ตามปกติ',
                textAlign: TextAlign.center,
                style: t.bodyMedium!.copyWith(color: p.error),
              ),
            ),
          if (fresh) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Text(
                'ผลที่บันทึกไว้${cache.createdAt == null ? '' : ' (${formatRelativeThai(cache.createdAt!)})'} · วัตถุดิบและเงื่อนไขเดียวกับด้านบน ไม่ต้องขอ AI ใหม่',
                style: t.bodySmall,
              ),
            ),
            ...cards(RecipeSource.aiSaved),
            if (cache.rejectedNotes.isNotEmpty)
              Text(
                'AI ตอบมาบางสูตรที่ข้อมูลไม่ครบจึงไม่ได้แสดง (${cache.rejectedNotes.length} สูตร)',
                style: t.bodySmall,
              ),
            Text(
              'สูตรจาก AI ยังไม่ผ่านการตรวจสอบโดยคน เวลาเป็นค่าประมาณ ควรใช้วิจารณญาณก่อนปรุง',
              style: t.bodySmall,
            ),
            const SizedBox(height: Space.sm),
            if (scope.ai.hasKey) requestButton('ขอเมนูจาก AI ใหม่'),
          ] else ...[
            if (cache != null && cache.recipes.isNotEmpty) ...[
              Panel(
                color: p.surfaceAlt,
                padding: const EdgeInsets.all(Space.md),
                child: Text(
                  'มีสูตร AI ${cache.recipes.length} เมนูจากครั้งก่อน แต่ขอด้วยวัตถุดิบ/เงื่อนไขที่ต่างจากตอนนี้ จึงแสดงเป็นผลเก่า',
                  style: t.bodySmall!.copyWith(color: p.ink),
                ),
              ),
              const SizedBox(height: Space.sm),
              ...cards(RecipeSource.aiStale),
            ],
            if (scope.ai.hasKey)
              requestButton(
                _aiError != null
                    ? 'ลองใหม่'
                    : 'ขอเมนูจาก AI ตามวัตถุดิบและเงื่อนไขนี้',
              ),
          ],
        ],
      ],
    );
  }
}
