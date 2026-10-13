import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/formatters.dart';
import '../../models/scan_record.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/content_width.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/scan_thumb.dart';
import '../ingredient_result_screen.dart';

/// แท็บ "ประวัติ": รายการสแกนย้อนหลัง ปัดเพื่อลบ (เลิกทำได้) ล้างทั้งหมดได้จากเมนู
class HistoryScreen extends StatelessWidget {
  /// สลับไปแท็บสแกน (ใช้กับปุ่มใน empty state)
  final VoidCallback onStartScan;

  const HistoryScreen({super.key, required this.onStartScan});

  Future<void> _confirmClear(BuildContext context) async {
    final scope = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ล้างประวัติทั้งหมด?'),
        content: const Text(
          'รายการสแกนและรูปที่บันทึกไว้ในเครื่องจะถูกลบ และกู้คืนไม่ได้',
        ),
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
      scope.settings.medium();
      final cleared = await scope.history.clear();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              cleared
                  ? 'ล้างประวัติแล้ว'
                  : 'ล้างประวัติไม่สำเร็จ (บันทึกลงเครื่องไม่ได้) ข้อมูลที่ลบไม่ได้ยังอยู่',
            ),
          ),
        );
    }
  }

  void _delete(BuildContext context, ScanRecord record) {
    final scope = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    scope.settings.light();
    final saved = scope.history.remove(record.id);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('ลบรายการแล้ว'),
          action: SnackBarAction(
            label: 'เลิกทำ',
            onPressed: () async {
              if (!await scope.history.undoRemoval(record.id)) {
                say(
                  'เลิกทำแล้ว แต่ยังบันทึกลงเครื่องไม่สำเร็จ รายการอาจหายเมื่อปิดแอป',
                );
              }
            },
          ),
        ),
      ).closed.then((reason) {
        if (reason != SnackBarClosedReason.action) {
          scope.history.finalizeRemoval(record.id);
        }
      });
    saved.then((ok) {
      if (!ok) say('ลบไม่สำเร็จ (บันทึกลงเครื่องไม่ได้) รายการยังอยู่');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final records = scope.history.records;
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติ'),
        actions: [
          if (records.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'ตัวเลือก',
              onSelected: (v) {
                if (v == 'clear') _confirmClear(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'clear',
                  child: Text('ล้างประวัติทั้งหมด'),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: records.isEmpty
              ? EmptyState(
                  icon: Icons.history,
                  title: 'ยังไม่มีประวัติ',
                  message:
                      'ผลการสแกนจะถูกบันทึกไว้ที่นี่\nเปิดดูย้อนหลังได้แม้ไม่มีอินเทอร์เน็ต',
                  actionLabel: 'เริ่มสแกน',
                  onAction: onStartScan,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Space.screen,
                    Space.xs,
                    Space.screen,
                    Space.xl,
                  ),
                  itemCount: records.length,
                  itemBuilder: (context, i) {
                    final r = records[i];
                    return Dismissible(
                      key: ValueKey(
                        '${r.id}#${scope.history.restoreEpoch(r.id)}',
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _delete(context, r),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: Space.xl),
                        margin: const EdgeInsets.only(bottom: Space.md),
                        decoration: BoxDecoration(
                          color: p.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Radii.lg),
                        ),
                        child: Icon(Icons.delete_outline, color: p.error),
                      ),
                      child: _HistoryTile(
                        record: r,
                        onTap: () => Navigator.of(
                          context,
                        ).push(IngredientResultScreen.routeForRecord(r)),
                        onDelete: () => _delete(context, r),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final meta = [
      formatRelativeThai(record.createdAt),
      '${record.ingredients.length} วัตถุดิบ',
      if (record.manual) 'เลือกเอง',
      if (record.aiRecipes.isNotEmpty) 'มีสูตร AI',
    ].join(' · ');
    final needsReview = !record.isConfirmed;
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
              children: [
                ScanThumb(record: record, width: 72, height: 72),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium,
                      ),
                      const SizedBox(height: Space.xxs),
                      Text(meta, style: t.bodySmall),
                      if (needsReview) ...[
                        const SizedBox(height: Space.xxs),
                        Text(
                          '${record.status.label} · แตะเพื่อตรวจและยืนยัน',
                          style: t.labelMedium!.copyWith(color: p.accent),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'ลบรายการ',
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: p.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
