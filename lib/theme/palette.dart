import 'package:flutter/material.dart';

/// พาเลตต์สีของแอป (สว่าง/มืด) อิงชุด CI "กิ๋นหยังดีจ้าว" v1.0
/// อ่านผ่าน `context.palette`  ค่าทุกคู่ตัวอักษร/พื้นผ่านคอนทราสต์ WCAG AA
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;

  /// พื้นผิวรอง (อุ่นกว่า surface เล็กน้อย) ใช้กับกล่องข้อมูล/ช่องกรอก
  final Color surfaceAlt;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;
  final Color onAccent;

  /// สีเหลืองทองของแบรนด์ ใช้เน้นเล็กน้อย (ดาว/ไฮไลต์) ไม่ใช้กับตัวอักษร
  final Color gold;

  /// สีเขียวสำหรับสถานะ "มีแล้ว/เสร็จแล้ว"
  final Color success;
  final Color error;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.gold,
    required this.success,
    required this.error,
  });

  /// พื้นสีเน้นอ่อน ใช้กับแท็ก/ป้าย/ตัวบ่งชี้
  Color get accentSoft => accent.withValues(alpha: 0.10);
  Color get successSoft => success.withValues(alpha: 0.12);
  Color get goldSoft => gold.withValues(alpha: 0.22);

  static const light = AppPalette(
    background: Color(0xFFFFF5D6), // cream
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFFFAEB),
    ink: Color(0xFF2B1713),
    muted: Color(0xFF766258),
    line: Color(0xFFEBDDB4),
    accent: Color(0xFFB82C1D), // action
    onAccent: Color(0xFFFFFFFF),
    gold: Color(0xFFF2A81D),
    success: Color(0xFF2E7D32),
    error: Color(0xFFB3261E),
  );

  static const dark = AppPalette(
    background: Color(0xFF211410),
    surface: Color(0xFF2D1E19),
    surfaceAlt: Color(0xFF382620),
    ink: Color(0xFFFFF5D6),
    muted: Color(0xFFB8A395),
    line: Color(0xFF4B3730),
    accent: Color(0xFFFF7A5F),
    onAccent: Color(0xFF2B1713),
    gold: Color(0xFFFFC24D),
    success: Color(0xFF81C784),
    error: Color(0xFFFFB4AB),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? muted,
    Color? line,
    Color? accent,
    Color? onAccent,
    Color? gold,
    Color? success,
    Color? error,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      gold: gold ?? this.gold,
      success: success ?? this.success,
      error: error ?? this.error,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
