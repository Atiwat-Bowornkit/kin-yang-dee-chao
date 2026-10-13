import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';

/// ป้าย "สูตรจาก AI" (compact = แสดงแค่ "AI")
class AiBadge extends StatelessWidget {
  final bool compact;

  const AiBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 1),
      decoration: BoxDecoration(
        color: p.accentSoft,
        border: Border.all(color: p.accent.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: p.accent),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              compact ? 'AI' : 'สูตรจาก AI',
              style: context.text.labelSmall!.copyWith(color: p.accent),
            ),
          ),
        ],
      ),
    );
  }
}
