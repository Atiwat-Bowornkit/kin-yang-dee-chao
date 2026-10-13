import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../data/catalog/ingredients_catalog.dart';
import '../../models/ingredient.dart';
import '../../models/ingredient_recognition_result.dart';
import '../../models/scan_record.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/bottom_cta.dart';
import '../../widgets/content_width.dart';
import '../../widgets/kitchen_selector.dart';
import '../../widgets/section_heading.dart';
import '../ingredient_picker_sheet.dart';
import '../ingredient_result_screen.dart';
import '../../core/emoji_support.dart';

/// ขั้นตรวจและยืนยันวัตถุดิบ: ภาพต้นฉบับ → แก้ชื่อ/ลบ/เพิ่ม → เลือกของในครัว → ยืนยัน
/// ผลจาก AI ที่ยังไม่ยืนยันจะไม่ถูกใช้หาเมนูหรือส่งให้ AI แนะนำสูตร
class IngredientReviewScreen extends StatefulWidget {
  final String recordId;

  const IngredientReviewScreen({super.key, required this.recordId});

  static Route<void> route(String recordId) => MaterialPageRoute(
    builder: (_) => IngredientReviewScreen(recordId: recordId),
  );

  @override
  State<IngredientReviewScreen> createState() => _IngredientReviewScreenState();
}

class _IngredientReviewScreenState extends State<IngredientReviewScreen> {
  static const _max = IngredientRecognitionResult.maxIngredients;

  late final ScanRecord? _record = AppScope.read(
    context,
  ).history.byId(widget.recordId);
  late List<DetectedIngredient> _items = [...?_record?.ingredients];
  late List<IngredientRename> _renames = [...?_record?.renames];
  late Set<String> _kitchen = effectiveKitchen(
    _record,
    AppScope.read(context).settings.kitchen,
  );
  bool _dirty = false;
  bool _saving = false;
  bool _draftWarned = false;

  bool get _isDraft => _record?.status == ScanStatus.draft;

  ChangeSet get _changes =>
      ChangeSet.compute(_record?.detected ?? const [], _items, _renames);

  void _changed() {
    // ชื่อที่แก้แล้วถูกลบทิ้ง → ไม่นับเป็น "แก้ชื่อ" (ชื่อเดิมจะนับเป็น "ลบ")
    final names = {for (final i in _items) i.nameTh};
    _renames = [
      for (final r in _renames)
        if (names.contains(r.to)) r,
    ];
    _dirty = true;
    setState(() {});
    final r = _record;
    if (r != null && _isDraft) {
      final messenger = ScaffoldMessenger.of(context);
      AppScope.read(context).history
          .updateDraft(
            r.copyWith(
              ingredients: _items,
              renames: _renames,
              kitchen: _kitchen,
            ),
          )
          .then((saved) {
            if (!saved && !_draftWarned && mounted) {
              _draftWarned = true;
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'ยังบันทึกร่างลงเครื่องไม่สำเร็จ ตรวจต่อได้ แต่ถ้าปิดแอปอาจกู้คืนร่างนี้ไม่ได้',
                    ),
                  ),
                );
            }
          });
    }
  }

  void _remove(DetectedIngredient i) {
    AppScope.read(context).settings.selection();
    _items.remove(i);
    _changed();
  }

  Future<void> _rename(DetectedIngredient item) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: item.nameTh),
    );
    if (newName == null || !mounted) return;
    final clean = IngredientRecognitionResult.cleanName(newName);
    if (clean.isEmpty || clean == item.nameTh) return;
    final next = DetectedIngredient.fromName(clean, source: item.source);
    if (_items.any((i) => !identical(i, item) && i.nameTh == next.nameTh)) {
      _snack('มี "${next.nameTh}" อยู่ในรายการแล้ว');
      return;
    }
    // หาชื่อต้นฉบับจาก AI (ถ้าเคยแก้มาแล้ว ใช้ชื่อเดิมก่อนแก้ครั้งแรก)
    final detectedNames = {
      for (final d in _record?.detected ?? const <DetectedIngredient>[])
        d.nameTh,
    };
    String? original;
    for (final r in _renames) {
      if (r.to == item.nameTh) original = r.from;
    }
    original ??= detectedNames.contains(item.nameTh) ? item.nameTh : null;
    if (original != null) {
      _renames = [
        for (final r in _renames)
          if (r.from != original) r,
      ];
      if (next.nameTh != original) {
        _renames.add(IngredientRename(original, next.nameTh));
      }
    }
    final idx = _items.indexOf(item);
    _items[idx] = next;
    _changed();
  }

  Future<void> _addMore() async {
    final updated = await showIngredientPicker(
      context,
      initial: _items,
      title: 'เพิ่มหรือลบวัตถุดิบ',
      confirmLabel: 'ใช้รายการนี้',
    );
    if (updated == null || !mounted) return;
    // รายการที่มีอยู่เดิมคงที่มาเดิมไว้ รายการใหม่ = ผู้ใช้เพิ่มเอง
    _items = [
      for (final u in updated)
        _items.firstWhere(
          (e) => e.id == u.id && e.nameTh == u.nameTh,
          orElse: () => u.withSource(IngredientSource.user),
        ),
    ];
    _changed();
  }

  Future<void> _confirm() async {
    if (_items.isEmpty || _saving) return;
    final scope = AppScope.read(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    scope.settings.medium();
    final ok = await scope.history.confirm(
      widget.recordId,
      ingredients: List.of(_items),
      renames: List.of(_renames),
      kitchen: {..._kitchen},
    );
    if (!mounted) return;
    if (!ok) {
      // ยังไม่ยืนยัน: ร่างยังอยู่ครบ (ในเครื่องและหน้าจอ) ผู้ใช้กดยืนยันใหม่ได้
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'ยืนยันไม่สำเร็จ: บันทึกลงเครื่องไม่ได้ (ที่เก็บข้อมูลอาจเต็ม)\nรายการที่ตรวจยังอยู่ครบ กดยืนยันใหม่ได้',
            ),
          ),
        );
      return;
    }
    await scope.settings.setKitchen(_kitchen);
    if (!mounted) return;
    navigator.pushReplacement(IngredientResultScreen.route(widget.recordId));
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// ออกจากหน้าโดยยังไม่ยืนยัน
  Future<void> _onExit() async {
    final navigator = Navigator.of(context);
    if (!_isDraft) {
      if (!_dirty) {
        navigator.pop();
        return;
      }
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ทิ้งการแก้ไข?'),
          content: const Text('รายการที่แก้ไว้ยังไม่ได้ยืนยัน จะไม่ถูกบันทึก'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('แก้ต่อ'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ทิ้งการแก้ไข'),
            ),
          ],
        ),
      );
      if (discard == true) navigator.pop();
      return;
    }
    final scope = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยังไม่ได้ยืนยันวัตถุดิบ'),
        content: const Text(
          'เก็บผลสแกนนี้ไว้ตรวจต่อภายหลัง หรือทิ้งไปเลย? ผลที่ยังไม่ยืนยันจะไม่อยู่ในประวัติ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: Text(
              'ทิ้งผลสแกน',
              style: TextStyle(color: ctx.palette.error),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('keep'),
            child: const Text('เก็บไว้ก่อน'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ตรวจต่อ'),
          ),
        ],
      ),
    );
    if (choice == 'discard') {
      final ok = await scope.history.discardDraft();
      if (!ok) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'ทิ้งผลสแกนไม่สำเร็จ (บันทึกลงเครื่องไม่ได้) ผลสแกนยังอยู่ในหน้าสแกน',
              ),
            ),
          );
      }
      navigator.pop();
    } else if (choice == 'keep') {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ตรวจวัตถุดิบ')),
        body: const Center(child: Text('ไม่พบรายการนี้แล้ว')),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onExit();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('ตรวจวัตถุดิบ')),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.screen,
                Space.xs,
                Space.screen,
                Space.xxl,
              ),
              children: [
                _ImageHeader(record: record),
                const SizedBox(height: Space.lg),
                _Notice(record: record),
                const SizedBox(height: Space.xl),
                SectionHeading(
                  'วัตถุดิบที่มี',
                  trailing: '${_items.length}/$_max',
                  padding: const EdgeInsets.only(bottom: Space.sm),
                ),
                if (_items.isEmpty)
                  _EmptyItems(onAdd: _addMore, isPhoto: !record.manual)
                else
                  Panel(
                    child: Column(
                      children: [
                        for (final i in _items)
                          _ItemRow(
                            key: ValueKey('row:${i.id}:${i.nameTh}'),
                            item: i,
                            renamedFrom: _renames
                                .where((r) => r.to == i.nameTh)
                                .map((r) => r.from)
                                .firstOrNull,
                            onRename: () => _rename(i),
                            onRemove: () => _remove(i),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: Space.sm),
                OutlinedButton.icon(
                  onPressed: _addMore,
                  icon: const Icon(Icons.add),
                  label: Text(
                    _items.isEmpty ? 'เลือกวัตถุดิบเอง' : 'เพิ่ม/ลบวัตถุดิบ',
                  ),
                ),
                if (!_changes.isEmpty && record.detected.isNotEmpty) ...[
                  const SizedBox(height: Space.sm),
                  _ChangeSummary(changes: _changes),
                ],
                const SizedBox(height: Space.xxl),
                SectionHeading(
                  'ของพื้นฐานในครัว',
                  trailing: '${_kitchen.length} อย่าง',
                  padding: const EdgeInsets.only(bottom: Space.xs),
                ),
                Text(
                  'แอปไม่ได้ตรวจของเหล่านี้จากรูป — เลือกเฉพาะที่มีจริง เมนูที่ต้องใช้ของที่ไม่ได้เลือกจะแสดงว่าต้องเตรียมเพิ่ม',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: Space.md),
                KitchenSelector(
                  selected: _kitchen,
                  onChanged: (v) {
                    _kitchen = v;
                    _changed();
                  },
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomCta(
          child: FilledButton.icon(
            onPressed: _items.isEmpty || _saving ? null : _confirm,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              _items.isEmpty
                  ? 'เพิ่มวัตถุดิบอย่างน้อย 1 อย่าง'
                  : 'ยืนยันวัตถุดิบและหาเมนู (${_items.length})',
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageHeader extends StatelessWidget {
  final ScanRecord record;

  const _ImageHeader({required this.record});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final path = AppScope.read(context).images.pathFor(record.imageFile);
    if (record.manual || path == null || kIsWeb) {
      return Panel(
        color: p.surfaceAlt,
        padding: const EdgeInsets.all(Space.lg),
        child: Row(
          children: [
            Icon(
              record.manual
                  ? Icons.checklist
                  : Icons.image_not_supported_outlined,
              color: p.muted,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                record.manual
                    ? 'เลือกวัตถุดิบเอง (ไม่มีรูป)'
                    : 'ไม่มีรูปของการสแกนนี้',
                style: t.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'เปิดดูรูปเต็มจอ',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => FullImageScreen(path: path),
          ),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.lg),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: p.surfaceAlt,
                    child: Center(
                      child: Text('ไม่พบไฟล์รูป', style: t.bodySmall),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: Space.sm,
              bottom: Space.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.zoom_out_map,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ดูเต็มจอ',
                      style: t.labelMedium!.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ดูรูปเต็มจอ ซูมได้
class FullImageScreen extends StatelessWidget {
  final String path;

  const FullImageScreen({super.key, required this.path});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('รูปต้นฉบับ'),
    ),
    body: InteractiveViewer(
      maxScale: 5,
      child: Center(
        child: Image.file(
          File(path),
          errorBuilder: (_, _, _) =>
              const Text('ไม่พบไฟล์รูป', style: TextStyle(color: Colors.white)),
        ),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  final ScanRecord record;

  const _Notice({required this.record});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final detected = record.detected.length;
    final reported = record.aiReportedCount;
    final over = reported != null && reported > detected
        ? 'AI ตอบมา $reported รายการ แสดงได้ไม่เกิน ${IngredientRecognitionResult.maxIngredients} รายการ (ตัดรายการซ้ำ/เกินออกแล้ว) เพิ่มเองได้ถ้ายังขาด'
        : null;
    final (IconData icon, String title, String body) = switch (record.status) {
      ScanStatus.draft when record.manual => (
        Icons.checklist,
        'ตรวจรายการก่อนหาเมนู',
        'แก้ไขได้ตามต้องการ แล้วกดยืนยัน',
      ),
      ScanStatus.draft =>
        detected == 0
            ? (
                Icons.search_off,
                'AI ไม่พบวัตถุดิบในภาพนี้',
                'ลองถ่ายใหม่ให้เห็นวัตถุดิบชัด ๆ มีแสงพอ หรือเพิ่มรายการเองได้เลย',
              )
            : (
                Icons.fact_check_outlined,
                'AI ตรวจพบ $detected รายการ — ตรวจให้ถูกก่อนหาเมนู',
                'AI อาจตอบผิดหรือตกหล่น แก้ชื่อ ลบ หรือเพิ่มได้ แอปจะใช้เฉพาะรายการที่คุณยืนยัน',
              ),
      ScanStatus.legacy => (
        Icons.history_toggle_off,
        'รายการจากแอปเวอร์ชันก่อน',
        'บันทึกก่อนมีขั้นยืนยันวัตถุดิบ กรุณาตรวจและยืนยันก่อนใช้หาเมนู',
      ),
      ScanStatus.confirmed => (
        Icons.edit_note,
        'แก้ไขรายการที่ยืนยันแล้ว',
        'เมื่อยืนยันอีกครั้ง เมนูจะคำนวณใหม่ สูตร AI เดิมจะถูกแสดงเป็นผลเก่า',
      ),
    };
    return Panel(
      color: Color.alphaBlend(p.gold.withValues(alpha: 0.16), p.surface),
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: p.ink),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: t.bodySmall!.copyWith(color: p.ink)),
                if (over != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(over, style: t.bodySmall!.copyWith(color: p.ink)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final DetectedIngredient item;
  final String? renamedFrom;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  const _ItemRow({
    super.key,
    required this.item,
    required this.renamedFrom,
    required this.onRename,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final tags = <String>[
      if (renamedFrom != null)
        'แก้จาก "$renamedFrom"'
      else if (item.source != null)
        item.source!.label,
      if (!item.known) 'ไม่อยู่ในฐานข้อมูล',
      if (item.isPantry) 'ของในครัว',
    ];
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.only(left: Space.lg, right: Space.xs),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line, width: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              item.emoji == null ? '•' : safeEmoji(item.emoji!),
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.nameTh, style: t.bodyLarge),
                  if (tags.isNotEmpty)
                    Text(tags.join(' · '), style: t.bodySmall),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'แก้ชื่อ ${item.nameTh}',
            onPressed: onRename,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'ลบ ${item.nameTh}',
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline, color: p.error),
          ),
        ],
      ),
    );
  }
}

class _ChangeSummary extends StatelessWidget {
  final ChangeSet changes;

  const _ChangeSummary({required this.changes});

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (changes.added.isNotEmpty) 'เพิ่ม ${changes.added.length}',
      if (changes.removed.isNotEmpty) 'ลบ ${changes.removed.length}',
      if (changes.renamed.isNotEmpty) 'แก้ชื่อ ${changes.renamed.length}',
    ];
    return Text(
      'แก้จากผล AI: ${parts.join(' · ')}',
      style: context.text.bodySmall,
    );
  }
}

class _EmptyItems extends StatelessWidget {
  final VoidCallback onAdd;
  final bool isPhoto;

  const _EmptyItems({required this.onAdd, required this.isPhoto});

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Panel(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ยังไม่มีวัตถุดิบในรายการ', style: t.titleSmall),
          const SizedBox(height: Space.xs),
          Text(
            isPhoto
                ? 'กดย้อนกลับเพื่อถ่าย/เลือกรูปใหม่ หรือกดปุ่มด้านล่างเพื่อเลือกวัตถุดิบเอง'
                : 'กดปุ่มด้านล่างเพื่อเลือกวัตถุดิบ',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// ของในครัวที่ใช้กับรายการ: ค่าที่ยืนยันไว้ หรือค่าเริ่มต้นจากตั้งค่าสำหรับรายการที่ยังไม่เคยยืนยันของในครัว
Set<String> effectiveKitchen(ScanRecord? record, Set<String> defaults) {
  if (record == null ||
      (record.kitchen.isEmpty && record.confirmedAt == null)) {
    return {...defaults};
  }
  return {...record.kitchen};
}

/// ชื่อไทยของของในครัว (ใช้ในหน้าอื่นด้วย)
String kitchenNames(Set<String> ids) => [
  for (final i in IngredientCatalog.all)
    if (i.pantry && ids.contains(i.id)) i.nameTh,
].join(', ');

/// กล่องแก้ชื่อ: ถือ TextEditingController เอง เพื่อให้ dispose หลังแอนิเมชันปิดจบ
class _RenameDialog extends StatefulWidget {
  final String initial;

  const _RenameDialog({required this.initial});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('แก้ชื่อวัตถุดิบ'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: IngredientRecognitionResult.maxNameLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.of(context).pop(v),
        decoration: const InputDecoration(hintText: 'ชื่อวัตถุดิบ'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}
