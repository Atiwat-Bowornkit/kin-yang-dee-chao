import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import '../../core/app_scope.dart';
import '../../data/recipe_repository.dart';
import '../../models/scan_record.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/content_width.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/scan_thumb.dart';
import '../../widgets/section_heading.dart';
import '../analyzing_screen.dart';
import '../ingredient_picker_sheet.dart';
import '../ingredient_result_screen.dart';
import '../review/ingredient_review_screen.dart';
import '../recipe_detail_screen.dart';
import '../search/search_screen.dart';
import '../settings/ai_settings_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/app_shell.dart' show ShellTab;

/// แท็บ "สแกน": ถ่ายภาพ/เลือกรูป/เลือกวัตถุดิบเอง → เมนูแนะนำวันนี้ → สแกนล่าสุด
class ScanScreen extends StatefulWidget {
  /// สลับไปแท็บอื่นของแถบนำทาง (ใช้กับปุ่ม "ดูทั้งหมด")
  final ValueChanged<int> onOpenTab;

  /// ใช้ในเทสต์เพื่อจำลองการเลือกรูป
  final ImagePicker? picker;

  const ScanScreen({super.key, required this.onOpenTab, this.picker});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final _picker = widget.picker ?? ImagePicker();

  XFile? _image;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    // Android อาจปิดแอประหว่างเปิดกล้อง (หน่วยความจำไม่พอ) → กู้รูปที่ถ่ายไว้กลับมา
    if (!kIsWeb && Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostImage());
    }
  }

  Future<void> _recoverLostImage() async {
    try {
      final lost = await _picker.retrieveLostData();
      if (!mounted || lost.isEmpty) return;
      final file = lost.file;
      if (file != null) {
        setState(() => _image = file);
        _showMessage(
          'กู้รูปที่ถ่ายไว้ก่อนแอปถูกปิดแล้ว กด "วิเคราะห์วัตถุดิบ" เพื่อทำต่อ',
        );
      } else if (lost.exception != null) {
        _showMessage('เปิดกล้อง/แกลเลอรีครั้งก่อนไม่สำเร็จ กรุณาลองใหม่');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('retrieveLostData failed: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null || !mounted) return; // ผู้ใช้ยกเลิก
      setState(() => _image = picked);
    } catch (e) {
      if (kDebugMode) debugPrint('pickImage failed: $e');
      if (mounted) {
        final noCamera =
            e is PlatformException && e.code == 'no_available_camera';
        _showMessage(
          noCamera
              ? 'ไม่พบกล้องบนอุปกรณ์นี้ ลองเลือกรูปจากแกลเลอรีแทน'
              : 'ไม่สามารถเปิดกล้องหรือแกลเลอรีได้\nกรุณาตรวจสอบสิทธิ์การเข้าถึงในการตั้งค่าเครื่อง',
        );
      }
    }
  }

  Future<void> _analyze() async {
    final image = _image;
    if (image == null || _analyzing) return;
    final scope = AppScope.read(context);
    if (!scope.ai.hasKey) {
      _showMessage(
        'ต้องตั้งค่าการเชื่อมต่อ AI ก่อนจึงจะวิเคราะห์รูปได้',
        action: SnackBarAction(label: 'ตั้งค่า', onPressed: _openAiSettings),
      );
      return;
    }
    scope.settings.light();
    setState(() => _analyzing = true);
    final error = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        transitionDuration: Motion.normal,
        pageBuilder: (_, _, _) => AnalyzingScreen(
          image: image,
          // สำเร็จแล้วล้างรูปออก กลับมาจะเห็นหน้าเริ่มต้นและสแกนล่าสุด
          onSuccess: () {
            if (mounted) setState(() => _image = null);
          },
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (!mounted) return;
    setState(() => _analyzing = false);
    if (error != null) _showMessage(error);
  }

  /// เลือกวัตถุดิบเอง: ปุ่มยืนยันในตัวเลือกคือขั้นยืนยันรายการ (ไม่ต้องผ่านหน้าตรวจซ้ำ)
  Future<void> _pickManually() async {
    final scope = AppScope.read(context);
    final navigator = Navigator.of(context);
    final picked = await showIngredientPicker(
      context,
      title: 'เลือกวัตถุดิบที่มี',
      confirmLabel: 'ยืนยันและหาเมนู',
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final now = DateTime.now();
    final record = ScanRecord(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      ingredients: picked,
      manual: true,
      status: ScanStatus.confirmed,
      confirmedAt: now,
      kitchen: scope.settings.kitchen,
      conditions: scope.settings.conditions,
    );
    final ok = await scope.history.add(record);
    if (!ok && mounted) {
      _showMessage(
        'บันทึกลงประวัติไม่สำเร็จ ยังดูเมนูได้ แต่รายการนี้อาจหายเมื่อเปิดแอปใหม่',
      );
    }
    navigator.push(IngredientResultScreen.route(record.id));
  }

  Future<void> _discardDraft() async {
    final scope = AppScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ทิ้งผลสแกนที่ยังไม่ยืนยัน?'),
        content: const Text('รูปและผลตรวจของการสแกนนี้จะถูกลบ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('ทิ้ง', style: TextStyle(color: ctx.palette.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final discarded = await scope.history.discardDraft();
      if (!discarded && mounted) {
        _showMessage(
          'ทิ้งผลสแกนไม่สำเร็จ (บันทึกลงเครื่องไม่ได้) ผลสแกนยังอยู่',
        );
      }
    }
  }

  void _showMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  void _removeImage() {
    if (_analyzing) return;
    AppScope.read(context).settings.selection();
    setState(() => _image = null);
  }

  void _openSearch() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));

  void _openSettings() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  void _openAiSettings() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const AiSettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final recent = scope.history.records.take(6).toList();
    final draft = scope.history.draft;
    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, Space.sm, 0, Space.xxl),
            children: [
              _pad(_buildHeader()),
              if (!scope.ai.hasKey) ...[
                const SizedBox(height: Space.lg),
                _pad(_AiSetupBanner(onTap: _openAiSettings)),
              ],
              if (draft != null && _image == null) ...[
                const SizedBox(height: Space.lg),
                _pad(
                  _DraftBanner(
                    record: draft,
                    onResume: () => Navigator.of(
                      context,
                    ).push(IngredientReviewScreen.route(draft.id)),
                    onDiscard: _discardDraft,
                  ),
                ),
              ],
              const SizedBox(height: Space.xl),
              _pad(
                _image == null ? _buildInputSection() : _buildPreviewSection(),
              ),
              const SizedBox(height: Space.xxl),
              _buildDailyPicks(),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: Space.xxl),
                _buildRecent(recent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pad(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.screen),
    child: child,
  );

  Widget _buildHeader() {
    final p = context.palette;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BrandLogo(size: 64),
            const Spacer(),
            IconButton(
              tooltip: 'ค้นหาสูตรอาหาร',
              onPressed: _openSearch,
              icon: const Icon(Icons.search, size: 26),
            ),
            IconButton(
              tooltip: 'ตั้งค่า',
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined, size: 24),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Text('มีวัตถุดิบ\nแต่ไม่รู้จะทำอะไร?', style: t.displaySmall),
        const SizedBox(height: Space.sm),
        Text(
          'ถ่ายรูปวัตถุดิบที่มี แล้วให้กิ๋นหยังดีจ้าวแนะนำเมนู พร้อมบอกว่าต้องซื้ออะไรเพิ่ม',
          style: t.bodyMedium!.copyWith(color: p.muted, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    final p = context.palette;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.xl),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _pickImage(ImageSource.camera),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.xl),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      p.accent.withValues(alpha: 0.14),
                      p.surface,
                    ),
                    Color.alphaBlend(p.gold.withValues(alpha: 0.22), p.surface),
                  ],
                ),
                border: Border.all(color: p.line),
              ),
              padding: const EdgeInsets.all(Space.xl),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_camera,
                      color: p.onAccent,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ถ่ายภาพวัตถุดิบ', style: t.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          'วางไว้ด้วยกันหลายอย่างก็ได้ AI จะดูให้',
                          style: t.bodySmall!.copyWith(
                            color: p.ink.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: p.accent),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('จากแกลเลอรี'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickManually,
                icon: const Icon(Icons.checklist),
                label: const Text('เลือกเอง'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.xl),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: kIsWeb
                    ? Image.network(_image!.path, fit: BoxFit.cover)
                    : Image.file(
                        File(_image!.path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: p.surfaceAlt),
                      ),
              ),
            ),
            Positioned(
              top: Space.md,
              right: Space.md,
              child: Material(
                color: p.surface.withValues(alpha: 0.92),
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _analyzing ? null : _removeImage,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.md + 2,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 16, color: p.ink),
                        const SizedBox(width: Space.xs),
                        Text(
                          'เอารูปออก',
                          style: context.text.labelMedium!.copyWith(
                            color: p.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        FilledButton.icon(
          onPressed: _analyzing ? null : _analyze,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('วิเคราะห์วัตถุดิบ'),
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _analyzing
                    ? null
                    : () => _pickImage(ImageSource.camera),
                child: const Text('ถ่ายใหม่'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: OutlinedButton(
                onPressed: _analyzing
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                child: const Text('เลือกภาพใหม่'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyPicks() {
    final picks = const RecipeRepository().dailyPicks();
    // ความสูงตามขนาดตัวอักษรของผู้ใช้: ภาพ + ช่องว่าง + ชื่อ 1 บรรทัด + ข้อมูล 1 บรรทัด
    final scaler = MediaQuery.textScalerOf(context);
    const tileWidth = 150.0;
    final rowHeight =
        tileWidth * 0.78 +
        Space.sm +
        scaler.scale(15) * 1.4 +
        scaler.scale(13) * 1.5 +
        Space.xs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pad(
          SectionHeading(
            'เมนูแนะนำวันนี้',
            padding: const EdgeInsets.only(bottom: Space.sm),
            action: TextButton(
              onPressed: _openSearch,
              child: const Text('ดูทั้งหมด'),
            ),
          ),
        ),
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.screen),
            itemCount: picks.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.md),
            itemBuilder: (context, i) => RecipeTile(
              recipe: picks[i],
              width: tileWidth,
              heroScope: 'daily',
              onTap: () => Navigator.of(context).push(
                RecipeDetailScreen.route(
                  RecipeMatch.browse(picks[i]),
                  heroScope: 'daily',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecent(List<ScanRecord> recent) {
    final scaler = MediaQuery.textScalerOf(context);
    // ภาพ 104 + ช่องว่าง + ชื่อ 2 บรรทัด (bodyMedium height 1.5)
    final rowHeight = 104 + Space.sm + scaler.scale(14) * 1.5 * 2 + Space.xs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pad(
          SectionHeading(
            'สแกนล่าสุด',
            padding: const EdgeInsets.only(bottom: Space.sm),
            action: TextButton(
              onPressed: () => widget.onOpenTab(ShellTab.history),
              child: const Text('ดูทั้งหมด'),
            ),
          ),
        ),
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.screen),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.md),
            itemBuilder: (context, i) => _RecentCard(
              record: recent[i],
              onTap: () => Navigator.of(
                context,
              ).push(IngredientResultScreen.routeForRecord(recent[i])),
            ),
          ),
        ),
      ],
    );
  }
}

/// ผลสแกนที่ยังไม่ได้ยืนยัน (เช่น ออกจากหน้าตรวจ หรือแอปถูกปิดระหว่างตรวจ)
class _DraftBanner extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  const _DraftBanner({
    required this.record,
    required this.onResume,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    return Panel(
      color: Color.alphaBlend(p.accent.withValues(alpha: 0.08), p.surface),
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.sm,
        Space.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScanThumb(record: record, width: 48, height: 48),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('มีผลสแกนที่ยังไม่ยืนยัน', style: t.titleSmall),
                    Text(
                      record.ingredients.isEmpty
                          ? 'AI ไม่พบวัตถุดิบ — เพิ่มเองได้'
                          : record.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onDiscard, child: const Text('ทิ้ง')),
              const SizedBox(width: Space.xs),
              // ธีมกำหนดปุ่ม Filled ให้กว้างเต็มแถว จึงต้องกำหนดขนาดเองเมื่ออยู่ใน Row
              FilledButton.tonal(
                style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
                onPressed: onResume,
                child: const Text('ตรวจต่อ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiSetupBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _AiSetupBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    return Material(
      color: p.goldSoft,
      borderRadius: BorderRadius.circular(Radii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            children: [
              Icon(Icons.key_outlined, color: p.ink),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ตั้งค่า AI ก่อนสแกน', style: t.titleSmall),
                    Text(
                      'ใส่ API key เพื่อให้วิเคราะห์รูปได้ ส่วนการเลือกวัตถุดิบเองและสูตรในแอปใช้ได้เลย',
                      style: t.bodySmall!.copyWith(
                        color: p.ink.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: p.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onTap;

  const _RecentCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'เปิดผลสแกน ${record.title}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: SizedBox(
          width: 128,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScanThumb(record: record, width: 128, height: 104),
              const SizedBox(height: Space.sm),
              Text(
                record.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
