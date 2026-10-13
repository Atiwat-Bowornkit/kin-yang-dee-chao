import 'package:flutter/material.dart';

import '../models/cooking_conditions.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';

/// เปิดฟอร์มเงื่อนไขการทำอาหาร คืนค่าใหม่ หรือ null ถ้าปิดโดยไม่บันทึก
Future<CookingConditions?> showConditionsSheet(
  BuildContext context,
  CookingConditions initial,
) => showModalBottomSheet<CookingConditions>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ConditionsForm(initial: initial),
);

class ConditionsForm extends StatefulWidget {
  final CookingConditions initial;

  const ConditionsForm({super.key, required this.initial});

  @override
  State<ConditionsForm> createState() => _ConditionsFormState();
}

class _ConditionsFormState extends State<ConditionsForm> {
  late CookingConditions _c = widget.initial;

  void _toggleEquipment(Equipment e, bool on) {
    final next = {...?_c.equipment};
    on ? next.add(e) : next.remove(e);
    // ไม่เหลืออุปกรณ์ที่เลือก = กลับเป็น "ไม่ระบุ" (ไม่ใช่ "ไม่มีเตา")
    setState(() => _c = _c.copyWith(equipment: next.isEmpty ? null : next));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final eq = _c.equipment;
    String timeLabel(int? m) => m == null ? 'ไม่จำกัด' : 'ไม่เกิน $m นาที';

    // ปุ่มยืนยันอยู่นอกส่วนที่เลื่อน จึงกดได้เสมอแม้จอเล็ก/ตัวอักษรใหญ่
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Space.screen,
              0,
              Space.screen,
              Space.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('เงื่อนไขการทำอาหาร', style: t.titleLarge),
                const SizedBox(height: Space.xs),
                Text(
                  'ใช้กรองสูตรในแอป และเป็นข้อกำหนดเมื่อขอเมนูจาก AI',
                  style: t.bodySmall,
                ),
                const SizedBox(height: Space.lg),
                Text('เวลาที่มี', style: t.titleSmall),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final m in CookingConditions.timeOptions)
                      ChoiceChip(
                        label: Text(timeLabel(m)),
                        selected: _c.maxMinutes == m,
                        onSelected: (_) =>
                            setState(() => _c = _c.copyWith(maxMinutes: m)),
                      ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    Expanded(child: Text('จำนวนที่', style: t.titleSmall)),
                    IconButton.outlined(
                      tooltip: 'ลดจำนวนที่',
                      onPressed: _c.servings > CookingConditions.minServings
                          ? () => setState(
                              () => _c = _c.copyWith(servings: _c.servings - 1),
                            )
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${_c.servings} ที่',
                        textAlign: TextAlign.center,
                        style: t.titleMedium,
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'เพิ่มจำนวนที่',
                      onPressed: _c.servings < CookingConditions.maxServings
                          ? () => setState(
                              () => _c = _c.copyWith(servings: _c.servings + 1),
                            )
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                Text('อุปกรณ์ที่มี', style: t.titleSmall),
                const SizedBox(height: Space.xs),
                Text('"ไม่ระบุ" = ไม่กรองตามอุปกรณ์', style: t.bodySmall),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('ไม่ระบุ'),
                      selected: eq == null,
                      onSelected: (_) =>
                          setState(() => _c = _c.copyWith(equipment: null)),
                    ),
                    ChoiceChip(
                      label: const Text('ไม่มีเตา'),
                      selected: eq != null && eq.isEmpty,
                      onSelected: (_) => setState(
                        () => _c = _c.copyWith(equipment: <Equipment>{}),
                      ),
                    ),
                    for (final e in Equipment.values)
                      FilterChip(
                        label: Text(e.label),
                        selected: eq?.contains(e) ?? false,
                        onSelected: (on) => _toggleEquipment(e, on),
                      ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                Text('ความเผ็ด', style: t.titleSmall),
                const SizedBox(height: Space.sm),
                SegmentedButton<SpicePreference>(
                  segments: [
                    for (final s in SpicePreference.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {_c.spice},
                  onSelectionChanged: (v) =>
                      setState(() => _c = _c.copyWith(spice: v.first)),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            Space.screen,
            Space.sm,
            Space.screen,
            Space.md + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: () => setState(
                  () => _c = CookingConditions(servings: _c.servings),
                ),
                child: const Text('ล้างเงื่อนไข'),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_c),
                  child: const Text('ใช้เงื่อนไขนี้'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// แถบสรุปเงื่อนไข แตะเพื่อแก้
class ConditionsBar extends StatelessWidget {
  final CookingConditions conditions;
  final VoidCallback onEdit;

  const ConditionsBar({
    super.key,
    required this.conditions,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    return Semantics(
      button: true,
      label: 'แก้เงื่อนไขการทำอาหาร: ${conditions.summary.join(', ')}',
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: p.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.md,
                Space.md,
                Space.md,
              ),
              child: Row(
                children: [
                  Icon(Icons.tune, color: p.accent),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('เงื่อนไขการทำอาหาร', style: t.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          conditions.summary.join(' · '),
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Text('แก้ไข', style: t.labelLarge!.copyWith(color: p.accent)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
