import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/app_scope.dart';
import '../models/recipe.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/content_width.dart';
import '../core/emoji_support.dart';

/// โหมดทำอาหาร: ทีละขั้นตอนแบบเต็มจอ ตัวใหญ่ หน้าจอไม่ดับ ปัดซ้าย/ขวาเพื่อเปลี่ยนขั้น
class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;
  final int servings;

  const CookingModeScreen({
    super.key,
    required this.recipe,
    required this.servings,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  final _pages = PageController();
  int _index = 0;

  List<String> get _steps => widget.recipe.steps;

  /// ขั้นตอนทั้งหมด + หน้า "เสร็จแล้ว"
  int get _count => _steps.length + 1;
  bool get _isDone => _index == _steps.length;

  @override
  void initState() {
    super.initState();
    _setWakelock(true);
  }

  @override
  void dispose() {
    _setWakelock(false);
    _pages.dispose();
    super.dispose();
  }

  Future<void> _setWakelock(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (e) {
      // ไม่มี plugin (เช่น ในเทสต์) → ใช้งานต่อได้ตามปกติ
      if (kDebugMode) debugPrint('wakelock: $e');
    }
  }

  void _go(int i) {
    if (i < 0 || i >= _count) return;
    AppScope.read(context).settings.selection();
    _pages.animateToPage(
      i,
      duration: Motion.normal,
      curve: Curves.easeOutCubic,
    );
  }

  void _showIngredients() {
    final factor = widget.servings / widget.recipe.servings;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final t = context.text;
        final p = context.palette;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(
              Space.screen,
              0,
              Space.screen,
              Space.xl,
            ),
            children: [
              Text('ส่วนผสม (${widget.servings} ที่)', style: t.titleLarge),
              const SizedBox(height: Space.md),
              for (final i in widget.recipe.ingredients)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
                  child: Row(
                    children: [
                      Text(
                        i.emoji == null ? '•' : safeEmoji(i.emoji!),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(child: Text(i.name, style: t.bodyLarge)),
                      Text(
                        i.amountLabel(factor),
                        style: t.bodyMedium!.copyWith(color: p.muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final progress = (_index + 1) / _count;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'ปิดโหมดทำอาหาร',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.recipe.nameTh, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton.icon(
            onPressed: _showIngredients,
            icon: const Icon(Icons.list_alt_outlined, size: 20),
            label: const Text('ส่วนผสม'),
          ),
          const SizedBox(width: Space.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: Motion.normal,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 4,
              color: _isDone ? p.success : p.accent,
              backgroundColor: p.line,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _count,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => i == _steps.length
                      ? _DonePage(onClose: () => Navigator.of(context).pop())
                      : _StepPage(
                          number: i + 1,
                          total: _steps.length,
                          text: _steps[i],
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.screen,
                  Space.sm,
                  Space.screen,
                  Space.lg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _index == 0 ? null : () => _go(_index - 1),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('ก่อนหน้า'),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isDone ? null : () => _go(_index + 1),
                        icon: Icon(
                          _index == _steps.length - 1
                              ? Icons.check
                              : Icons.chevron_right,
                        ),
                        label: Text(
                          _index == _steps.length - 1 ? 'เสร็จแล้ว' : 'ถัดไป',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _isDone
                    ? 'ทำครบทุกขั้นตอนแล้ว'
                    : 'ปัดซ้าย/ขวาเพื่อเปลี่ยนขั้นตอน · หน้าจอจะไม่ดับ',
                style: t.bodySmall,
              ),
              const SizedBox(height: Space.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  final int number;
  final int total;
  final String text;

  const _StepPage({
    required this.number,
    required this.total,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.all(Space.screen),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: c.maxHeight - Space.screen * 2,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ขั้นตอนที่ $number จาก $total',
                style: t.titleMedium!.copyWith(color: p.accent),
              ),
              const SizedBox(height: Space.lg),
              Text(text, style: t.headlineMedium!.copyWith(height: 1.45)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonePage extends StatelessWidget {
  final VoidCallback onClose;

  const _DonePage({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.successSoft,
                shape: BoxShape.circle,
              ),
              child: const Text('🎉', style: TextStyle(fontSize: 52)),
            ),
            const SizedBox(height: Space.xl),
            Text('เสร็จแล้ว! น่ากินมาก', style: t.headlineSmall),
            const SizedBox(height: Space.sm),
            Text(
              'ขอให้อร่อยกับมื้อนี้นะ',
              style: t.bodyMedium!.copyWith(color: p.muted),
            ),
            const SizedBox(height: Space.xl),
            SizedBox(
              width: 220,
              child: FilledButton(
                onPressed: onClose,
                child: const Text('กลับไปที่สูตร'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
