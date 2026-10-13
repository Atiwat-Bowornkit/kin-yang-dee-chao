import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../data/catalog/ingredients_catalog.dart';
import '../models/ingredient.dart';
import '../models/ingredient_recognition_result.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/ingredient_chip.dart';

/// เปิดตัวเลือกวัตถุดิบ (แก้ผลสแกน / เลือกเองโดยไม่ต้องถ่ายรูป)
/// คืนรายการใหม่ หรือ null ถ้าผู้ใช้ปิดโดยไม่ยืนยัน
Future<List<DetectedIngredient>?> showIngredientPicker(
  BuildContext context, {
  List<DetectedIngredient> initial = const [],
  String title = 'เลือกวัตถุดิบที่มี',
  String confirmLabel = 'ดูเมนูที่ทำได้',
}) {
  return showModalBottomSheet<List<DetectedIngredient>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // คีย์บอร์ดเปิด: ย่นแผ่นขึ้นเหนือคีย์บอร์ด (ไม่ให้ช่องค้นหา/ปุ่มยืนยันถูกบัง)
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scroll) => IngredientPicker(
          initial: initial,
          title: title,
          confirmLabel: confirmLabel,
          scrollController: scroll,
        ),
      ),
    ),
  );
}

class IngredientPicker extends StatefulWidget {
  final List<DetectedIngredient> initial;
  final String title;
  final String confirmLabel;
  final ScrollController? scrollController;

  const IngredientPicker({
    super.key,
    required this.initial,
    required this.title,
    required this.confirmLabel,
    this.scrollController,
  });

  @override
  State<IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<IngredientPicker> {
  late final List<DetectedIngredient> _selected = [...widget.initial];
  final _query = TextEditingController();
  final _focus = FocusNode();

  static const _max = IngredientRecognitionResult.maxIngredients;

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _isSelected(Ingredient i) =>
      _selected.any((s) => s.known && s.id == i.id);

  void _toggle(Ingredient i) {
    AppScope.read(context).settings.selection();
    setState(() {
      final idx = _selected.indexWhere((s) => s.known && s.id == i.id);
      if (idx >= 0) {
        _selected.removeAt(idx);
        _limitHit = false;
      } else if (_selected.length < _max) {
        _selected.add(DetectedIngredient.fromCatalog(i));
      } else {
        _showLimit();
      }
    });
  }

  /// แจ้งเตือนในแผ่นนี้เอง (snackbar จะถูกบังอยู่หลัง bottom sheet)
  bool _limitHit = false;

  void _showLimit() => _limitHit = true;

  void _addTyped() {
    final name = IngredientRecognitionResult.cleanName(_query.text);
    if (name.isEmpty) return;
    final item = DetectedIngredient.fromName(name);
    setState(() {
      if (_selected.any((s) => s.id == item.id || s.nameTh == item.nameTh)) {
        // มีอยู่แล้ว
      } else if (_selected.length < _max) {
        _selected.add(item);
      } else {
        _showLimit();
      }
      _query.clear();
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final q = _query.text.trim();
    final matches = IngredientCatalog.search(q);
    final exact = IngredientCatalog.resolve(q) != null;
    // ชิปที่เลือก (สูงสุด 12 ชิป หลายแถว) ต้องไม่ดันส่วนอื่นจนล้น: จำกัดความสูงและเลื่อนในตัวเอง
    // คีย์บอร์ดเปิดอยู่ → ซ่อนชิปที่เลือกชั่วคราว (จำนวนยังแสดงที่หัวแผ่น) เพื่อให้ช่องค้นหา
    // ผลค้นหา และปุ่มยืนยันอยู่ในจอเหนือคีย์บอร์ดได้แม้ตัวอักษรขยายบนจอ 360×640
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    const selectedMaxHeight = 120.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.screen,
            0,
            Space.screen,
            Space.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: t.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _limitHit
                    ? 'เลือกได้สูงสุด $_max อย่าง'
                    : '${_selected.length}/$_max',
                style: t.bodySmall!.copyWith(
                  color: _limitHit ? p.accent : null,
                ),
              ),
            ],
          ),
        ),
        // วัตถุดิบที่เลือกแล้ว
        if (!keyboardOpen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.screen),
            child: AnimatedSize(
              duration: Motion.normal,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: double.infinity,
                child: _selected.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.sm),
                        child: Text(
                          'แตะวัตถุดิบด้านล่าง หรือพิมพ์ชื่อเพื่อเพิ่ม',
                          style: t.bodySmall,
                        ),
                      )
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: selectedMaxHeight,
                        ),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: Space.sm,
                            runSpacing: Space.sm,
                            children: [
                              for (final s in _selected)
                                IngredientChip(
                                  key: ValueKey('sel:${s.id}:${s.nameTh}'),
                                  ingredient: s,
                                  selected: true,
                                  onRemove: () => setState(() {
                                    _selected.remove(s);
                                    _limitHit = false;
                                  }),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.screen,
            Space.md,
            Space.screen,
            Space.sm,
          ),
          child: TextField(
            controller: _query,
            focusNode: _focus,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _addTyped(),
            decoration: InputDecoration(
              hintText: 'ค้นหาหรือพิมพ์ชื่อวัตถุดิบ',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'ล้าง',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_query.clear),
                    ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(
              Space.screen,
              Space.xs,
              Space.screen,
              Space.lg,
            ),
            children: q.isNotEmpty
                ? [
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        for (final i in matches.take(24))
                          IngredientChip(
                            ingredient: DetectedIngredient.fromCatalog(i),
                            selected: _isSelected(i),
                            onTap: () => _toggle(i),
                          ),
                        if (!exact)
                          ActionChip(
                            avatar: Icon(Icons.add, size: 18, color: p.accent),
                            label: Text('เพิ่ม "$q"'),
                            onPressed: _addTyped,
                          ),
                      ],
                    ),
                    if (matches.isEmpty) ...[
                      const SizedBox(height: Space.md),
                      Text(
                        'ไม่พบในรายการ — กด "เพิ่ม" เพื่อใช้ชื่อที่พิมพ์ได้เลย',
                        style: t.bodySmall,
                      ),
                    ],
                  ]
                : [for (final c in IngredientCategory.values) ..._category(c)],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.screen,
              Space.sm,
              Space.screen,
              Space.md,
            ),
            child: FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(List.of(_selected)),
              child: Text(
                _selected.isEmpty
                    ? widget.confirmLabel
                    : '${widget.confirmLabel} (${_selected.length})',
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _category(IngredientCategory c) {
    final items = [
      for (final i in IngredientCatalog.selectable)
        if (i.category == c) i,
    ];
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: Space.md, bottom: Space.sm),
        child: Text(c.label, style: context.text.titleSmall),
      ),
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (final i in items)
            IngredientChip(
              ingredient: DetectedIngredient.fromCatalog(i),
              selected: _isSelected(i),
              onTap: () => _toggle(i),
            ),
        ],
      ),
    ];
  }
}
