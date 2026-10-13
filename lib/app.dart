import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'constants/app_constants.dart';
import 'core/app_scope.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell/app_shell.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// รากของแอป: รับ state ที่สร้างไว้แล้ว (ดู main.dart) แล้วแชร์ผ่าน [AppScope]
class KinYangDeeChaoApp extends StatelessWidget {
  final AppScopeData data;

  const KinYangDeeChaoApp({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return AppScope(data: data, child: const _AppRoot());
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    // ฟังเฉพาะการตั้งค่า (ธีม) — การเปลี่ยนประวัติ/เมนูโปรดไม่ทำให้ MaterialApp สร้างใหม่
    final settings = AppScope.read(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appName,
        theme: lightAppTheme,
        darkTheme: darkAppTheme,
        themeMode: settings.themeMode,
        locale: const Locale('th', 'TH'),
        supportedLocales: const [Locale('th', 'TH'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const _Gate(),
      ),
    );
  }
}

/// onboarding ครั้งแรก → แอปหลัก (เฟดสลับกัน)
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return AnimatedSwitcher(
      duration: Motion.slow,
      child: settings.onboardingDone
          ? const AppShell(key: ValueKey('shell'))
          : OnboardingScreen(
              key: const ValueKey('onboarding'),
              onDone: settings.completeOnboarding,
            ),
    );
  }
}
