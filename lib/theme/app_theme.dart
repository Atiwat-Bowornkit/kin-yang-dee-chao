import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';
import 'tokens.dart';

const String appFontFamily = 'Kanit';

/// ธีมที่สร้างไว้ครั้งเดียว (ไม่ต้องสร้างใหม่ทุกครั้งที่ state เปลี่ยน)
final ThemeData lightAppTheme = buildAppTheme(Brightness.light);
final ThemeData darkAppTheme = buildAppTheme(Brightness.dark);

/// ชุดตัวอักษรของแอป: Kanit ทุกขนาด, line-height ไม่ต่ำกว่า 1.3
/// เพื่อไม่ให้สระบน/วรรณยุกต์ภาษาไทยถูกตัด
TextTheme _textTheme(AppPalette p) {
  TextStyle s(double size, FontWeight w, double h, [Color? c]) => TextStyle(
    fontFamily: appFontFamily,
    fontSize: size,
    fontWeight: w,
    height: h,
    color: c ?? p.ink,
    letterSpacing: 0,
  );
  return TextTheme(
    displaySmall: s(32, FontWeight.w300, 1.3),
    headlineMedium: s(28, FontWeight.w400, 1.3),
    headlineSmall: s(24, FontWeight.w400, 1.32),
    titleLarge: s(20, FontWeight.w500, 1.35),
    titleMedium: s(17, FontWeight.w500, 1.4),
    titleSmall: s(15, FontWeight.w500, 1.4),
    bodyLarge: s(16, FontWeight.w400, 1.55),
    bodyMedium: s(14, FontWeight.w400, 1.5),
    bodySmall: s(13, FontWeight.w300, 1.5, p.muted),
    labelLarge: s(15, FontWeight.w500, 1.35),
    labelMedium: s(13, FontWeight.w500, 1.35),
    labelSmall: s(11.5, FontWeight.w500, 1.35),
  );
}

ThemeData buildAppTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final isDark = brightness == Brightness.dark;
  final text = _textTheme(p);

  // กำหนดทุกช่องสีที่ widget มาตรฐานใช้ เพื่อให้ popup/chip/dialog ใช้โทนครีม-น้ำตาลเดียวกัน
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: p.accentSoft,
    onPrimaryContainer: p.accent,
    secondary: p.accent,
    onSecondary: p.onAccent,
    secondaryContainer: Color.alphaBlend(p.accentSoft, p.surface),
    onSecondaryContainer: p.accent,
    tertiary: p.gold,
    onTertiary: const Color(0xFF2B1713),
    error: p.error,
    onError: isDark ? const Color(0xFF2B1713) : Colors.white,
    surface: p.surface,
    onSurface: p.ink,
    onSurfaceVariant: p.muted,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceAlt,
    surfaceContainerHighest: p.surfaceAlt,
    surfaceTint: Colors.transparent,
    outline: p.line,
    outlineVariant: p.line,
    inverseSurface: p.ink,
    onInverseSurface: p.background,
    inversePrimary: isDark ? AppPalette.light.accent : AppPalette.dark.accent,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.md),
  );

  OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.md),
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: appFontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    splashFactory: InkRipple.splashFactory,
    highlightColor: p.accent.withValues(alpha: 0.04),
    splashColor: p.accent.withValues(alpha: 0.08),
    dividerColor: p.line,
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    extensions: [p],
    textTheme: text,
    // ปุ่มย้อนกลับ/ท่าทางย้อนกลับแบบ predictive บน Android, สไลด์แบบ iOS บน Apple
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: p.surface,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: p.accentSoft,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium!.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w500
              : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? p.accent : p.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? p.accent : p.muted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.line,
        disabledForegroundColor: p.muted,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        elevation: 0,
        shape: shape,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        backgroundColor: p.surface,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        side: BorderSide(color: p.line),
        shape: shape,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        minimumSize: const Size(48, 44),
        textStyle: text.labelLarge!.copyWith(fontSize: 14),
        shape: shape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(48, 48),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.accentSoft,
      disabledColor: p.line,
      side: BorderSide(color: p.line),
      checkmarkColor: p.accent,
      deleteIconColor: p.muted,
      labelStyle: text.bodyMedium!.copyWith(color: p.ink),
      secondaryLabelStyle: text.bodyMedium!.copyWith(color: p.accent),
      padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      showCheckmark: false,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: text.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: p.line),
      ),
      elevation: 2,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.background,
      showDragHandle: true,
      dragHandleColor: p.line,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? p.ink : AppPalette.light.ink,
      contentTextStyle: text.bodyMedium!.copyWith(
        color: isDark ? p.background : Colors.white,
      ),
      actionTextColor: isDark
          ? AppPalette.light.accent
          : AppPalette.dark.accent,
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium!.copyWith(color: p.muted),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.onAccent : p.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : p.line,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all(p.onAccent),
      side: BorderSide(color: p.muted, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.line,
      strokeWidth: 2,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        foregroundColor: p.ink,
        selectedForegroundColor: p.accent,
        selectedBackgroundColor: p.accentSoft,
        side: BorderSide(color: p.line),
        textStyle: text.labelLarge!.copyWith(fontSize: 14),
      ),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall,
      iconColor: p.muted,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: text.bodyLarge!.copyWith(
        color: p.muted,
        fontWeight: FontWeight.w300,
      ),
      labelStyle: text.bodyMedium!.copyWith(color: p.muted),
      helperStyle: text.bodySmall,
      prefixIconColor: p.muted,
      suffixIconColor: p.muted,
      border: inputBorder(p.line),
      enabledBorder: inputBorder(p.line),
      focusedBorder: inputBorder(p.accent, 1.4),
      errorBorder: inputBorder(p.error),
      focusedErrorBorder: inputBorder(p.error, 1.4),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? p.ink : AppPalette.light.ink,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      textStyle: text.labelMedium!.copyWith(
        color: isDark ? p.background : Colors.white,
      ),
    ),
  );
}
