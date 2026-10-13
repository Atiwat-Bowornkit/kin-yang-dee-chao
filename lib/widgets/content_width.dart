import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// จำกัดความกว้างเนื้อหาและจัดกึ่งกลาง (จอแท็บเล็ต/แนวนอนไม่ให้ยืดเกินไป)
class ContentWidth extends StatelessWidget {
  final Widget child;

  const ContentWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: child,
      ),
    );
  }
}
