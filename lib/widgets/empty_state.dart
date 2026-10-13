import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';

/// หน้าว่าง: ไอคอนในวงกลมสีอ่อน + หัวข้อ + คำอธิบาย + ปุ่ม (ถ้ามี)
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// false = ไม่ห่อด้วย scroll view (ใช้เมื่ออยู่ใน list อยู่แล้ว)
  final bool scrollable;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.restaurant_menu_outlined,
    this.actionLabel,
    this.onAction,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final content = Padding(
      padding: const EdgeInsets.all(Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: p.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 46, color: p.accent),
          ),
          const SizedBox(height: Space.xl),
          Text(title, textAlign: TextAlign.center, style: t.headlineSmall),
          const SizedBox(height: Space.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: t.bodyMedium!.copyWith(color: p.muted, height: 1.6),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: Space.xl),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200),
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
    if (!scrollable) return content;
    return Center(child: SingleChildScrollView(child: content));
  }
}
