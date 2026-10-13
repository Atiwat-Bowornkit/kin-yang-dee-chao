import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'ai_badge.dart';

/// หัวข้อส่วนของหน้า: ชื่อ (+ ป้าย AI) + ข้อความ/ปุ่มด้านขวา
class SectionHeading extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget? action;
  final bool aiBadge;
  final EdgeInsetsGeometry padding;

  const SectionHeading(
    this.title, {
    super.key,
    this.trailing,
    this.action,
    this.aiBadge = false,
    this.padding = const EdgeInsets.only(bottom: Space.md),
  });

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Padding(
      padding: padding,
      // ชื่อหัวข้อใช้พื้นที่เท่าที่ต้องการก่อน (ไม่แบ่งครึ่งกับฝั่งขวา) แล้วค่อยตัดด้วย … เมื่อไม่พอ
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: t.titleLarge,
                  ),
                ),
                if (aiBadge) ...[
                  const SizedBox(width: Space.sm),
                  const AiBadge(compact: true),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Space.sm),
            Text(trailing!, style: t.bodySmall),
          ],
          ?action,
        ],
      ),
    );
  }
}

/// กรอบพื้นผิวขอบบางสำหรับกลุ่มรายการ
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const Panel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: color ?? p.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: p.line),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
