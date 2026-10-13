import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../models/shopping_item.dart';
import '../../services/share_service.dart';
import '../../state/shopping_controller.dart' show AddNameResult;
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/content_width.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_heading.dart';
import '../../core/emoji_support.dart';

/// แท็บ "ซื้อของ": รายการของที่ต้องซื้อ (จากสูตร/พิมพ์เอง) จัดกลุ่มตามหมวด ติ๊กเมื่อซื้อแล้ว
class ShoppingScreen extends StatefulWidget {
  final ShareService share;

  const ShoppingScreen({super.key, this.share = const ShareService()});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toast(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  void _toastVia(ScaffoldMessengerState messenger, String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _add() async {
    final name = _input.text.trim();
    if (name.isEmpty) return;
    final scope = AppScope.read(context);
    scope.settings.selection();
    final result = await scope.shopping.addName(name);
    if (!mounted) return;
    _input.clear();
    _focus.requestFocus();
    switch (result) {
      case AddNameResult.duplicate:
        _toast('"$name" อยู่ในรายการแล้ว');
      case AddNameResult.saveFailed:
        _toast(
          'เพิ่ม "$name" ไม่สำเร็จ ยังบันทึกลงเครื่องไม่ได้ ลองอีกครั้งได้',
        );
      case AddNameResult.added || AddNameResult.revived || AddNameResult.empty:
        break;
    }
  }

  void _delete(ShoppingItem item) {
    final shopping = AppScope.read(context).shopping;
    final saved = shopping.remove(item.id);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('ลบ "${item.name}" แล้ว'),
          action: SnackBarAction(
            label: 'เลิกทำ',
            onPressed: () async {
              if (!await shopping.undoRemoval(item.id)) {
                _toastVia(
                  messenger,
                  'เลิกทำแล้ว แต่ยังบันทึกลงเครื่องไม่สำเร็จ รายการอาจหายเมื่อปิดแอป',
                );
              }
            },
          ),
        ),
      ).closed.then((reason) {
        if (reason != SnackBarClosedReason.action) {
          shopping.finalizeRemoval(item.id);
        }
      });
    saved.then((ok) {
      if (!ok) {
        _toastVia(
          messenger,
          'ลบ "${item.name}" ไม่สำเร็จ (บันทึกลงเครื่องไม่ได้) รายการยังอยู่',
        );
      }
    });
  }

  Future<void> _share() async {
    final shopping = AppScope.read(context).shopping;
    try {
      await widget.share.shareText(
        shopping.shareText(),
        subject: 'รายการซื้อของ',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('share failed: $e');
      if (mounted) _toast('แชร์ไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  Future<void> _menu(String value) async {
    final shopping = AppScope.read(context).shopping;
    switch (value) {
      case 'checked':
        final r = await shopping.clearChecked();
        if (mounted) {
          _toast(
            !r.saved
                ? 'ลบที่ซื้อแล้วไม่สำเร็จ (บันทึกลงเครื่องไม่ได้) รายการยังอยู่'
                : r.removed == 0
                ? 'ยังไม่มีรายการที่ซื้อแล้ว'
                : 'ลบที่ซื้อแล้ว ${r.removed} รายการ',
          );
        }
      case 'all':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ล้างรายการซื้อของทั้งหมด?'),
            content: const Text('รายการทั้งหมดจะถูกลบ และกู้คืนไม่ได้'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('ยกเลิก', style: TextStyle(color: ctx.palette.ink)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'ล้างทั้งหมด',
                  style: TextStyle(color: ctx.palette.error),
                ),
              ),
            ],
          ),
        );
        if (ok == true) {
          final cleared = await shopping.clear();
          if (mounted) {
            _toast(
              cleared
                  ? 'ล้างรายการซื้อของแล้ว'
                  : 'ล้างรายการซื้อของไม่สำเร็จ (บันทึกลงเครื่องไม่ได้) รายการยังอยู่',
            );
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final shopping = scope.shopping;
    final p = context.palette;
    final t = context.text;
    final groups = shopping.grouped;

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการซื้อของ'),
        actions: [
          if (shopping.remaining > 0)
            IconButton(
              tooltip: 'แชร์รายการ',
              icon: const Icon(Icons.ios_share),
              onPressed: _share,
            ),
          if (!shopping.isEmpty)
            PopupMenuButton<String>(
              tooltip: 'ตัวเลือก',
              onSelected: _menu,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'checked', child: Text('ลบที่ซื้อแล้ว')),
                PopupMenuItem(value: 'all', child: Text('ล้างทั้งหมด')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.screen,
              Space.xs,
              Space.screen,
              Space.xl,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              TextField(
                controller: _input,
                focusNode: _focus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  hintText: 'เพิ่มของที่ต้องซื้อ เช่น ไข่ไก่',
                  prefixIcon: const Icon(Icons.add_shopping_cart_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'เพิ่ม',
                    icon: Icon(Icons.add_circle, color: p.accent),
                    onPressed: _add,
                  ),
                ),
              ),
              if (shopping.isEmpty)
                const EmptyState(
                  scrollable: false,
                  icon: Icons.shopping_basket_outlined,
                  title: 'ยังไม่มีรายการซื้อของ',
                  message:
                      'ในหน้าสูตรอาหาร กด "เพิ่มของที่ยังไม่มี"\nหรือพิมพ์เพิ่มเองด้านบน',
                )
              else ...[
                const SizedBox(height: Space.lg),
                _ProgressCard(
                  done: shopping.checkedCount,
                  total: shopping.items.length,
                ),
                for (final e in groups.entries) ...[
                  const SizedBox(height: Space.xl),
                  SectionHeading(
                    e.key.label,
                    trailing: switch (e.value.where((i) => !i.checked).length) {
                      0 => 'ครบแล้ว ✓',
                      final n => '$n รายการ',
                    },
                    padding: const EdgeInsets.only(bottom: Space.sm),
                  ),
                  Panel(
                    child: Column(
                      children: [
                        for (final item in e.value)
                          Dismissible(
                            key: ValueKey(
                              '${item.id}#${shopping.restoreEpoch(item.id)}',
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _delete(item),
                            background: Container(
                              color: p.error.withValues(alpha: 0.12),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: Space.xl),
                              child: Icon(Icons.delete_outline, color: p.error),
                            ),
                            child: _ItemRow(
                              item: item,
                              onToggle: () async {
                                scope.settings.selection();
                                final messenger = ScaffoldMessenger.of(context);
                                if (!await shopping.toggle(item.id)) {
                                  _toastVia(
                                    messenger,
                                    'ยังบันทึกการติ๊กลงเครื่องไม่สำเร็จ สถานะอาจกลับเมื่อเปิดแอปใหม่',
                                  );
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: Space.md),
                Text(
                  'ปัดรายการไปทางซ้ายเพื่อลบ',
                  style: t.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int done;
  final int total;

  const _ProgressCard({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final complete = done == total;
    return Panel(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  complete
                      ? 'ซื้อครบแล้ว 🎉'
                      : 'เหลืออีก ${total - done} รายการ',
                  style: t.titleMedium,
                ),
              ),
              Text('$done/$total', style: t.bodySmall),
            ],
          ),
          const SizedBox(height: Space.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: total == 0 ? 0 : done / total),
              duration: Motion.normal,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                color: complete ? p.success : p.accent,
                backgroundColor: p.line,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;

  const _ItemRow({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final sub = [
      if (item.amount != null) item.amount!,
      if (item.recipes.isNotEmpty) 'ใช้ทำ ${item.recipes.join(', ')}',
    ].join(' · ');
    return Semantics(
      checked: item.checked,
      label: item.name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.sm,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.line, width: 0.6)),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Motion.fast,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: item.checked ? p.success : Colors.transparent,
                  border: Border.all(
                    color: item.checked ? p.success : p.muted,
                    width: 1.4,
                  ),
                ),
                child: item.checked
                    ? Icon(Icons.check, size: 16, color: p.surface)
                    : null,
              ),
              const SizedBox(width: Space.md),
              if (item.emoji != null) ...[
                Text(
                  safeEmoji(item.emoji!),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: Space.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: Motion.fast,
                      style: t.bodyLarge!.copyWith(
                        color: item.checked ? p.muted : p.ink,
                        decoration: item.checked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: p.muted,
                      ),
                      child: Text(item.name),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
