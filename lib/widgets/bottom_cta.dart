import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';

/// ปุ่มหลักของขั้นตอนที่ติดอยู่ด้านล่างจอ (อยู่เหนือ SafeArea เสมอ)
class BottomCta extends StatelessWidget {
  final Widget child;
  final Widget? above;

  const BottomCta({super.key, required this.child, this.above});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.background,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.line, width: 0.6)),
          ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (above != null) ...[
                    above!,
                    const SizedBox(height: Space.sm),
                  ],
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
