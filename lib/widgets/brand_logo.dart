import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// โลโก้แบรนด์ เลือกไฟล์ตามธีม: สว่าง = แดงอมส้ม, มืด = สีเต็ม (เหลือง/ส้ม) ตามคู่มือ CI
class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark
          ? 'assets/branding/logo_fullcolor.png'
          : 'assets/branding/logo_vermilion.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: AppConstants.appName,
    );
  }
}
