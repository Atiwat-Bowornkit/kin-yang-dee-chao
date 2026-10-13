import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../data/recipe_repository.dart';
import '../data/recommendation.dart';
import '../models/recipe.dart';
import '../state/shopping_controller.dart' show ShoppingSync;
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/ai_badge.dart';
import '../widgets/content_width.dart';
import '../widgets/favorite_button.dart';
import '../widgets/info_pill.dart';
import '../widgets/recipe_card.dart' show recipeHeroTag;
import '../widgets/explanation_panel.dart';
import '../widgets/recipe_cover.dart';
import '../widgets/section_heading.dart';
import 'cooking_mode_screen.dart';
import 'share_sheet.dart';
import 'shell/app_shell.dart';
import '../core/emoji_support.dart';

/// รายละเอียดเมนู: ภาพปก → ชื่อและข้อมูล → ส่วนผสม (ปรับจำนวนที่ได้) → วิธีทำ → โหมดทำอาหาร
class RecipeDetailScreen extends StatefulWidget {
  final RecipeMatch match;
  final String heroScope;

  /// เหตุผลที่แนะนำ (มีเมื่อเปิดจากผลการจับคู่วัตถุดิบ)
  final RecommendationExplanation? explanation;

  /// จำนวนที่เริ่มต้น (เช่น ตามเงื่อนไขที่ผู้ใช้เลือก) — null = ตามสูตร
  final int? servings;

  const RecipeDetailScreen({
    super.key,
    required this.match,
    this.heroScope = '',
    this.explanation,
    this.servings,
  });

  static Route<void> route(
    RecipeMatch match, {
    String heroScope = '',
    RecommendationExplanation? explanation,
    int? servings,
  }) => MaterialPageRoute(
    builder: (_) => RecipeDetailScreen(
      match: match,
      heroScope: heroScope,
      explanation: explanation,
      servings: servings,
    ),
  );

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  RecipeMatch get _m => widget.match;
  Recipe get _r => _m.recipe;

  late int _servings = (widget.servings ?? _r.servings).clamp(1, _maxServings);

  /// ส่วนผสมที่ติ๊กว่ามี/เตรียมแล้ว (เริ่มต้น = วัตถุดิบที่ยืนยัน + ของในครัวที่เลือกไว้)
  late final Set<RecipeIngredient> _prepared = {..._m.have, ..._m.staples};
  final Set<int> _doneSteps = {};

  static const _maxServings = 12;

  double get _factor => _servings / _r.servings;

  /// ส่วนผสมหลักเรียง: มีแล้ว → ที่ต้องเตรียม → ของเสริม (เครื่องปรุงแยกไว้ท้าย)
  List<RecipeIngredient> get _main => [
    ..._m.have.where((i) => !i.isPantry),
    ..._m.need,
    ..._m.optional,
  ];
  List<RecipeIngredient> get _staples => [
    ..._m.have.where((i) => i.isPantry),
    ..._m.staples,
    ..._m.pantryNeed,
  ];

  /// ของที่จะเพิ่มลงรายการซื้อ = ส่วนผสมจำเป็นทั้งหมดที่ยังไม่ได้ติ๊ก (ไม่รวมของเสริม)
  /// ไม่ยึดแค่ที่ขาดตอนเริ่มต้น: เอาติ๊กของที่มี/เครื่องปรุงในครัวออกแล้วต้องซื้อได้
  List<RecipeIngredient> get _missing => [
    for (final i in _r.ingredients)
      if (!i.optional && !_prepared.contains(i)) i,
  ];

  void _setServings(int v) {
    AppScope.read(context).settings.selection();
    setState(() => _servings = v.clamp(1, _maxServings));
  }

  void _togglePrepared(RecipeIngredient i) {
    AppScope.read(context).settings.selection();
    setState(() {
      if (!_prepared.add(i)) _prepared.remove(i);
    });
  }

  Future<void> _addMissingToShopping() async {
    final scope = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final items = _missing;
    scope.settings.light();
    final added = await scope.shopping.addFromRecipe(
      _r,
      items,
      factor: _factor,
    );
    if (!mounted) return;
    if (added == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('บันทึกรายการซื้อของลงเครื่องไม่สำเร็จ กรุณาลองใหม่'),
          ),
        );
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'อัปเดตปริมาณในรายการซื้อของแล้ว'
                : 'เพิ่ม $added รายการลงรายการซื้อของแล้ว',
          ),
          action: SnackBarAction(
            label: 'ดูรายการ',
            onPressed: () => goToShellTab(context, ShellTab.shopping),
          ),
        ),
      );
  }

  void _startCooking() {
    AppScope.read(context).settings.medium();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CookingModeScreen(recipe: _r, servings: _servings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final scope = AppScope.of(context);
    final missing = _missing;
    final syncs = [
      for (final i in missing) scope.shopping.syncState(_r, i, factor: _factor),
    ];
    // ปิดปุ่มเฉพาะเมื่อรายการซื้อของมีของสูตรนี้ครบ "และปริมาณตรงกับตอนนี้" แล้วเท่านั้น
    final allInList =
        missing.isNotEmpty && syncs.every((s) => s == ShoppingSync.current);
    final hasNew = syncs.any((s) => s == ShoppingSync.absent);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 260,
            backgroundColor: p.background,
            leading: const _CircleBack(),
            actions: [
              _CircleAction(
                child: IconButton(
                  tooltip: 'แชร์สูตร',
                  icon: const Icon(Icons.ios_share),
                  onPressed: () =>
                      showRecipeShareSheet(context, _r, servings: _servings),
                ),
              ),
              const SizedBox(width: Space.xs),
              _CircleAction(child: FavoriteButton(recipe: _r)),
              const SizedBox(width: Space.sm),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: RecipeCover(
                recipe: _r,
                radius: 0,
                emojiScale: 0.42,
                heroTag: recipeHeroTag(_r, widget.heroScope),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.screen,
                  Space.xl,
                  Space.screen,
                  Space.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_r.isAiGenerated) ...[
                      const AiBadge(),
                      const SizedBox(height: Space.sm),
                    ] else ...[
                      InfoPill(
                        icon: Icons.menu_book_outlined,
                        label: _r.sourceLabel,
                        color: p.accent,
                        filled: true,
                      ),
                      const SizedBox(height: Space.sm),
                    ],
                    Text(_r.nameTh, style: t.headlineMedium),
                    if (_r.description.isNotEmpty) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        _r.description,
                        style: t.bodyMedium!.copyWith(color: p.muted),
                      ),
                    ],
                    const SizedBox(height: Space.md),
                    _InfoGrid(recipe: _r),
                    const SizedBox(height: Space.xs),
                    Text(
                      _r.isAiGenerated
                          ? 'เวลาเป็นค่าประมาณจาก AI'
                          : 'แคลอรีเป็นค่าประมาณคร่าว ๆ ที่ผู้จัดทำใส่ไว้กับสูตร ไม่ได้คำนวณจากฐานข้อมูลโภชนาการ',
                      style: t.bodySmall,
                    ),
                    if (_r.tags.isNotEmpty) ...[
                      const SizedBox(height: Space.md),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in _r.tags)
                            InfoPill(
                              icon: Icons.label_outline,
                              label: tag.label,
                              color: p.accent,
                              filled: true,
                            ),
                        ],
                      ),
                    ],
                    if (_r.isAiGenerated) ...[
                      const SizedBox(height: Space.lg),
                      Panel(
                        color: p.goldSoft,
                        padding: const EdgeInsets.all(Space.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 20, color: p.ink),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Text(
                                'สูตรนี้สร้างโดย AI ปริมาณและขั้นตอนอาจไม่แม่นยำ ควรตรวจสอบก่อนปรุงจริง',
                                style: t.bodySmall!.copyWith(color: p.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (widget.explanation != null) ...[
                      const SizedBox(height: Space.xl),
                      ExplanationPanel(explanation: widget.explanation!),
                    ] else if (!_m.browsing) ...[
                      const SizedBox(height: Space.xl),
                      _HaveSummary(match: _m),
                    ],
                    const SizedBox(height: Space.xxl),
                    SectionHeading(
                      'ส่วนผสม',
                      trailing:
                          'ติ๊กแล้ว ${_prepared.length}/${_r.ingredients.length}',
                    ),
                    _ServingsStepper(
                      servings: _servings,
                      onChanged: _setServings,
                      max: _maxServings,
                    ),
                    const SizedBox(height: Space.md),
                    Panel(
                      child: Column(
                        children: [
                          for (final i in _main)
                            _IngredientRow(
                              ingredient: i,
                              factor: _factor,
                              checked: _prepared.contains(i),
                              have: _m.have.contains(i),
                              onTap: () => _togglePrepared(i),
                            ),
                          if (_staples.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              color: p.surfaceAlt,
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.lg,
                                vertical: Space.sm,
                              ),
                              child: Text(
                                'เครื่องปรุงพื้นฐาน',
                                style: t.labelMedium!.copyWith(color: p.muted),
                              ),
                            ),
                            for (final i in _staples)
                              _IngredientRow(
                                ingredient: i,
                                factor: _factor,
                                checked: _prepared.contains(i),
                                have: _m.have.contains(i),
                                kitchen: _m.staples.contains(i),
                                prepare:
                                    _m.pantryNeed.contains(i) && !_m.browsing,
                                onTap: () => _togglePrepared(i),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      'ติ๊กรายการที่มีอยู่แล้ว — ของจำเป็นที่ยังไม่ได้ติ๊กจะถูกเพิ่มลงรายการซื้อ (ของเสริม "ถ้ามี" ไม่ถูกเพิ่ม)',
                      style: t.bodySmall,
                    ),
                    if (missing.isNotEmpty) ...[
                      const SizedBox(height: Space.md),
                      OutlinedButton.icon(
                        onPressed: allInList ? null : _addMissingToShopping,
                        icon: Icon(
                          allInList
                              ? Icons.check
                              : Icons.add_shopping_cart_outlined,
                        ),
                        label: Text(
                          allInList
                              ? 'อยู่ในรายการซื้อของแล้ว'
                              : hasNew
                              ? 'เพิ่มของที่ยังไม่ได้ติ๊ก (${missing.length}) ลงรายการซื้อ'
                              : 'อัปเดตปริมาณในรายการซื้อของ (${missing.length})',
                        ),
                      ),
                    ],
                    const SizedBox(height: Space.xxl),
                    SectionHeading(
                      'วิธีทำ',
                      trailing: '${_r.steps.length} ขั้นตอน',
                    ),
                    for (var i = 0; i < _r.steps.length; i++)
                      _StepRow(
                        number: i + 1,
                        text: _r.steps[i],
                        isLast: i == _r.steps.length - 1,
                        done: _doneSteps.contains(i),
                        onTap: () => setState(() {
                          if (!_doneSteps.add(i)) _doneSteps.remove(i);
                        }),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.screen,
            Space.sm,
            Space.screen,
            Space.md,
          ),
          // ไม่ใช้ ContentWidth (Align จะขยายเต็มความสูงใน bottomNavigationBar)
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: FilledButton.icon(
                onPressed: _startCooking,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('เริ่มโหมดทำอาหาร'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ปุ่มกลมพื้นทึบบนภาพปก (อ่านง่ายทั้งตอนกางและยุบ)
class _CircleAction extends StatelessWidget {
  final Widget child;

  const _CircleAction({required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(left: Space.sm),
    child: _CircleAction(child: BackButton()),
  );
}

class _InfoGrid extends StatelessWidget {
  final Recipe recipe;

  const _InfoGrid({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    Widget cell(IconData icon, String label, String value) => Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: p.accent),
          const SizedBox(height: 2),
          Text(value, textAlign: TextAlign.center, style: t.titleSmall),
          Text(
            label,
            textAlign: TextAlign.center,
            style: t.bodySmall!.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        children: [
          cell(
            Icons.schedule,
            recipe.isAiGenerated ? 'เวลา (AI ประมาณ)' : 'เวลารวม',
            recipeTimeLabel(recipe),
          ),
          cell(
            difficultyIcon(recipe.difficulty),
            'ความยาก',
            recipe.difficulty.label,
          ),
          cell(
            Icons.bolt_outlined,
            'ต่อที่ (ประมาณ)',
            kcalLabel(recipe) ?? 'ไม่ทราบ',
          ),
          cell(Icons.restaurant_outlined, 'หมวด', recipe.category.label),
        ],
      ),
    );
  }
}

class _HaveSummary extends StatelessWidget {
  final RecipeMatch match;

  const _HaveSummary({required this.match});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final complete = match.need.isEmpty;
    final color = complete ? p.success : p.accent;
    return Panel(
      color: Color.alphaBlend(color.withValues(alpha: 0.08), p.surface),
      padding: const EdgeInsets.all(Space.lg),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.kitchen_outlined,
            color: color,
            size: 28,
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complete
                      ? 'มีวัตถุดิบหลักครบแล้ว'
                      : 'ขาดอีก ${match.need.length} อย่าง',
                  style: t.titleSmall!.copyWith(color: color),
                ),
                Text(
                  'คุณมี: ${match.haveNames.join(', ')}',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServingsStepper extends StatelessWidget {
  final int servings;
  final int max;
  final ValueChanged<int> onChanged;

  const _ServingsStepper({
    required this.servings,
    required this.onChanged,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    return Row(
      children: [
        Icon(Icons.people_outline, color: p.muted, size: 20),
        const SizedBox(width: Space.sm),
        Expanded(child: Text('ปริมาณสำหรับ', style: t.bodyMedium)),
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: p.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'ลดจำนวนที่',
                onPressed: servings > 1 ? () => onChanged(servings - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '$servings ที่',
                  textAlign: TextAlign.center,
                  style: t.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'เพิ่มจำนวนที่',
                onPressed: servings < max
                    ? () => onChanged(servings + 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final RecipeIngredient ingredient;
  final double factor;
  final bool checked;
  final bool have;
  final bool kitchen;
  final bool prepare;
  final VoidCallback onTap;

  const _IngredientRow({
    required this.ingredient,
    required this.factor,
    required this.checked,
    required this.have,
    required this.onTap,
    this.kitchen = false,
    this.prepare = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    return Semantics(
      checked: checked,
      label: '${ingredient.name} ${ingredient.amountLabel(factor)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.sm + 2,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.line, width: 0.6)),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Motion.fast,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: checked ? p.accent : Colors.transparent,
                  border: Border.all(
                    color: checked ? p.accent : p.muted,
                    width: 1.2,
                  ),
                ),
                child: checked
                    ? Icon(Icons.check, size: 14, color: p.onAccent)
                    : null,
              ),
              const SizedBox(width: Space.md),
              if (ingredient.emoji != null) ...[
                Text(
                  safeEmoji(ingredient.emoji!),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: Space.sm),
              ],
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: Motion.fast,
                      style: t.bodyLarge!.copyWith(
                        color: checked ? p.muted : p.ink,
                        decoration: checked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: p.muted,
                      ),
                      child: Text(ingredient.name),
                    ),
                    if (have)
                      _Tag('มีแล้ว', p.success)
                    else if (kitchen)
                      _Tag('มีในครัว', p.success)
                    else if (ingredient.optional)
                      _Tag('ถ้ามี', p.muted)
                    else if (prepare)
                      _Tag('ต้องเตรียม', p.accent),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(
                ingredient.amountLabel(factor),
                style: t.bodyMedium!.copyWith(color: p.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(Radii.xs),
    ),
    child: Text(text, style: context.text.labelSmall!.copyWith(color: color)),
  );
}

class _StepRow extends StatelessWidget {
  final int number;
  final String text;
  final bool isLast;
  final bool done;
  final VoidCallback onTap;

  const _StepRow({
    required this.number,
    required this.text,
    required this.isLast,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    return Semantics(
      checked: done,
      label: 'ขั้นตอนที่ $number $text',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // วงตัวเลข + เส้นเชื่อมขั้นตอน
              Column(
                children: [
                  AnimatedContainer(
                    duration: Motion.fast,
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done ? p.success : p.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: done
                        ? Icon(Icons.check, size: 18, color: p.surface)
                        : Text(
                            '$number',
                            style: t.labelLarge!.copyWith(color: p.accent),
                          ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: p.line,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    bottom: isLast ? 0 : Space.lg,
                  ),
                  child: Text(
                    text,
                    style: t.bodyLarge!.copyWith(color: done ? p.muted : p.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
