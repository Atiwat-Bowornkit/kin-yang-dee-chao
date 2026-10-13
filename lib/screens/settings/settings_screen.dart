import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../constants/app_constants.dart';
import '../../core/app_scope.dart';
import '../../data/recipe_repository.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/content_width.dart';
import '../../widgets/kitchen_selector.dart';
import '../../widgets/section_heading.dart';
import '../onboarding_screen.dart';
import 'ai_settings_screen.dart';

/// หน้า "ตั้งค่า": การเชื่อมต่อ AI, การแสดงผล, ข้อมูลในเครื่อง, ความช่วยเหลือ และเกี่ยวกับแอป
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('ยกเลิก', style: TextStyle(color: ctx.palette.ink)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action, style: TextStyle(color: ctx.palette.error)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _clear(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    required Future<bool> Function() run,
    required String done,
  }) async {
    final ok = await _confirm(
      context,
      title: title,
      message: message,
      action: action,
    );
    if (!ok || !context.mounted) return;
    final saved = await run();
    if (context.mounted) {
      _toast(
        context,
        saved
            ? done
            : 'ล้างไม่สำเร็จ (บันทึกลงเครื่องไม่ได้) ข้อมูลที่ลบไม่ได้ยังอยู่ กรุณาลองใหม่',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final p = context.palette;
    final t = context.text;

    final test = scope.ai.lastTest;
    final aiStatus = [
      scope.ai.keySource.label,
      if (!scope.ai.hasKey) 'สแกนรูปยังไม่ได้ (เลือกวัตถุดิบเองได้)',
      if (scope.ai.hasKey && test == null) 'ยังไม่ได้ทดสอบการเชื่อมต่อ',
      if (test != null)
        test.ok ? 'ทดสอบล่าสุด: สำเร็จ' : 'ทดสอบล่าสุด: ไม่สำเร็จ',
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.screen,
              Space.xs,
              Space.screen,
              Space.xxxl,
            ),
            children: [
              const SectionHeading('การเชื่อมต่อ AI'),
              Panel(
                child: _ActionRow(
                  icon: scope.ai.hasKey
                      ? Icons.check_circle
                      : Icons.key_outlined,
                  iconColor: scope.ai.hasKey ? p.success : p.accent,
                  title: 'บริการ AI และ API key',
                  subtitle: aiStatus,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                  ),
                ),
              ),
              const SizedBox(height: Space.xxl),
              const SectionHeading('ของพื้นฐานในครัว'),
              Panel(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ค่าเริ่มต้นสำหรับการสแกนครั้งถัดไป (แก้ได้ในหน้าตรวจวัตถุดิบทุกครั้ง) — ของที่ไม่ได้เลือกจะแสดงว่าต้องเตรียมเพิ่ม',
                      style: t.bodySmall,
                    ),
                    const SizedBox(height: Space.md),
                    KitchenSelector(
                      selected: settings.kitchen,
                      onChanged: settings.setKitchen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xxl),
              const SectionHeading('การแสดงผล'),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.lg,
                        Space.lg,
                        Space.lg,
                        Space.sm,
                      ),
                      child: Text('ธีม', style: t.bodySmall),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.lg,
                        0,
                        Space.lg,
                        Space.lg,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_outlined),
                              label: Text('ตามระบบ'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('สว่าง'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('มืด'),
                            ),
                          ],
                          selected: {settings.themeMode},
                          onSelectionChanged: (s) {
                            settings.selection();
                            settings.setThemeMode(s.first);
                          },
                        ),
                      ),
                    ),
                    const Divider(),
                    SwitchListTile(
                      value: settings.hapticsEnabled,
                      onChanged: (v) {
                        settings.setHaptics(v);
                        if (v) settings.selection();
                      },
                      title: const Text('การสั่นตอบสนอง'),
                      subtitle: const Text('สั่นเบา ๆ เมื่อกดปุ่มสำคัญ'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Space.lg,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xxl),
              const SectionHeading('ข้อมูลในเครื่อง'),
              Panel(
                child: Column(
                  children: [
                    _ActionRow(
                      icon: Icons.history,
                      title: 'ล้างประวัติการสแกน',
                      subtitle: '${scope.history.records.length} รายการ',
                      enabled: !scope.history.isEmpty,
                      onTap: () => _clear(
                        context,
                        title: 'ล้างประวัติทั้งหมด?',
                        message:
                            'รายการสแกนและรูปที่บันทึกไว้ในเครื่องจะถูกลบ และกู้คืนไม่ได้',
                        action: 'ล้างประวัติ',
                        run: scope.history.clear,
                        done: 'ล้างประวัติแล้ว',
                      ),
                    ),
                    const Divider(),
                    _ActionRow(
                      icon: Icons.favorite_border,
                      title: 'ล้างเมนูโปรด',
                      subtitle: '${scope.favorites.recipes.length} เมนู',
                      enabled: !scope.favorites.isEmpty,
                      onTap: () => _clear(
                        context,
                        title: 'ล้างเมนูโปรดทั้งหมด?',
                        message:
                            'เมนูที่บันทึกไว้ทั้งหมดจะถูกลบ และกู้คืนไม่ได้',
                        action: 'ล้างเมนูโปรด',
                        run: scope.favorites.clear,
                        done: 'ล้างเมนูโปรดแล้ว',
                      ),
                    ),
                    const Divider(),
                    _ActionRow(
                      icon: Icons.shopping_basket_outlined,
                      title: 'ล้างรายการซื้อของ',
                      subtitle: '${scope.shopping.items.length} รายการ',
                      enabled: !scope.shopping.isEmpty,
                      onTap: () => _clear(
                        context,
                        title: 'ล้างรายการซื้อของทั้งหมด?',
                        message: 'รายการทั้งหมดจะถูกลบ และกู้คืนไม่ได้',
                        action: 'ล้างรายการ',
                        run: scope.shopping.clear,
                        done: 'ล้างรายการซื้อของแล้ว',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xxl),
              const SectionHeading('ความช่วยเหลือ'),
              Panel(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: settings.demoMode,
                      onChanged: settings.setDemoMode,
                      title: const Text('โหมดสาธิต'),
                      subtitle: const Text(
                        'แสดงขั้นตอนการทำงานและบันทึกการเรียก AI (ไม่มีข้อมูลลับ) ในหน้าสรุปการวิเคราะห์',
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Space.lg,
                      ),
                    ),
                    const Divider(),
                    _ActionRow(
                      icon: Icons.school_outlined,
                      title: 'ดูวิธีใช้งานอีกครั้ง',
                      subtitle: 'แนะนำการใช้งานแอปทีละขั้น',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (ctx) => OnboardingScreen(
                            onDone: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xxl),
              const SectionHeading('เกี่ยวกับแอป'),
              const Panel(child: _AboutBlock()),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: enabled ? (iconColor ?? p.ink) : p.muted),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.bodyLarge!.copyWith(
                      color: enabled ? p.ink : p.muted,
                    ),
                  ),
                  Text(subtitle, style: t.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: p.muted),
          ],
        ),
      ),
    );
  }
}

class _AboutBlock extends StatelessWidget {
  const _AboutBlock();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandLogo(size: 64),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppConstants.appName, style: t.titleLarge),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snap) {
                        final v = snap.data;
                        return Text(
                          v == null
                              ? 'กำลังโหลดเวอร์ชัน…'
                              : 'เวอร์ชัน ${v.version} (${v.buildNumber})',
                          style: t.bodySmall,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text(
            AppConstants.tagline,
            style: t.bodyMedium!.copyWith(color: p.accent),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'ถ่ายภาพวัตถุดิบ ตรวจและยืนยันรายการ แล้วรับเมนูพร้อมเหตุผล ส่วนผสม วิธีทำ และรายการของที่ต้องซื้อเพิ่ม '
            '— มีสูตรในแอป ${RecipeRepository.recipes.length} เมนู ใช้ได้แม้ออฟไลน์ '
            'การตรวจรูปและคิดเมนูเพิ่มใช้โมเดลของผู้ให้บริการผ่าน API (แอปไม่ได้ฝึกโมเดลเอง)',
            style: t.bodySmall!.copyWith(height: 1.6),
          ),
          const SizedBox(height: Space.lg),
          const Divider(),
          const SizedBox(height: Space.lg),
          Text('ความเป็นส่วนตัว', style: t.titleSmall),
          const SizedBox(height: Space.xs),
          Text(
            'รูปที่สแกนจะถูกส่งไปยังบริการ AI ที่คุณตั้งค่าไว้เพื่อวิเคราะห์เท่านั้น '
            'ส่วนประวัติ เมนูโปรด รายการซื้อของ และรูปที่บันทึกจะเก็บไว้ในเครื่องของคุณ '
            'และลบได้ทุกเมื่อ API key ถูกเก็บแบบเข้ารหัสในเครื่อง',
            style: t.bodySmall!.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
