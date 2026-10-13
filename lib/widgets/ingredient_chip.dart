import 'package:flutter/material.dart';

import '../models/ingredient.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../core/emoji_support.dart';

/// ชิปวัตถุดิบ: emoji + ชื่อ, ลบได้ (ถ้ามี [onRemove]) หรือเลือกได้ (ถ้ามี [onTap])
class IngredientChip extends StatelessWidget {
  final DetectedIngredient ingredient;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final bool selected;

  const IngredientChip({
    super.key,
    required this.ingredient,
    this.onRemove,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final bg = selected ? p.accentSoft : p.surface;
    final border = selected ? p.accent.withValues(alpha: 0.6) : p.line;
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // ชิปที่ลบได้: ปุ่ม × สูงเต็มชิป 48dp
            padding: onRemove == null
                ? const EdgeInsets.fromLTRB(
                    Space.md,
                    Space.xs + 2,
                    Space.md,
                    Space.xs + 2,
                  )
                : const EdgeInsets.only(left: Space.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ingredient.emoji != null) ...[
                  Text(
                    safeEmoji(ingredient.emoji!),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    ingredient.nameTh,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium!.copyWith(
                      fontSize: 15,
                      color: selected ? p.accent : p.ink,
                    ),
                  ),
                ),
                // พื้นที่แตะของปุ่มลบ 44×48dp (รวมขอบชิปเป็น ≥48)
                if (onRemove != null)
                  Semantics(
                    label: 'เอา ${ingredient.nameTh} ออก',
                    button: true,
                    excludeSemantics: true,
                    child: InkResponse(
                      onTap: onRemove,
                      radius: 22,
                      child: SizedBox(
                        width: 44,
                        height: 48,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: p.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
