import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/scan_record.dart';
import '../theme/palette.dart';
import '../core/emoji_support.dart';

/// รูปย่อของการสแกน (ไม่มีรูป/เปิดไม่ได้ → emoji วัตถุดิบแรกบนพื้นสีอ่อน)
class ScanThumb extends StatelessWidget {
  final ScanRecord record;
  final double? width;
  final double? height;
  final double radius;

  const ScanThumb({
    super.key,
    required this.record,
    this.width,
    this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = height ?? width ?? 64;
    final emoji = record.ingredients
        .map((i) => i.emoji)
        .firstWhere((e) => e != null, orElse: () => null);
    final placeholder = Container(
      width: width,
      height: height,
      color: Color.alphaBlend(p.accentSoft, p.surfaceAlt),
      alignment: Alignment.center,
      child: record.manual || emoji != null
          ? Text(
              safeEmoji(emoji ?? '🧺'),
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontSize: size * 0.42),
            )
          : Icon(Icons.image_outlined, color: p.muted, size: size * 0.36),
    );

    final path = AppScope.read(context).images.pathFor(record.imageFile);
    Widget child = placeholder;
    if (path != null && !kIsWeb) {
      child = Image.file(
        File(path),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: 360,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}
