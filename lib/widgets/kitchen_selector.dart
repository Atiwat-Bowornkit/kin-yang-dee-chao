import 'package:flutter/material.dart';

import '../data/catalog/ingredients_catalog.dart';
import '../theme/tokens.dart';
import '../core/emoji_support.dart';

/// เลือกของพื้นฐานในครัวที่มีจริง (น้ำมัน น้ำปลา น้ำตาล ฯลฯ)
class KitchenSelector extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const KitchenSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final i in IngredientCatalog.all)
        if (i.pantry) i,
    ];
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final i in items)
          FilterChip(
            label: Text('${safeEmoji(i.emoji)} ${i.nameTh}'),
            selected: selected.contains(i.id),
            onSelected: (on) {
              final next = {...selected};
              on ? next.add(i.id) : next.remove(i.id);
              onChanged(next);
            },
          ),
      ],
    );
  }
}
