import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../core/app_scope.dart';
import '../../services/api_service.dart';
import '../../state/ai_config_controller.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/content_width.dart';
import '../../widgets/section_heading.dart';

/// ตั้งค่าบริการ AI: API key (เก็บเข้ารหัส), Base URL, โมเดล และทดสอบการเชื่อมต่อ
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

enum _TestState { idle, running, ok, failed }

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late final AiConfigController _ai = AppScope.read(context).ai;
  late final _key = TextEditingController(text: _ai.userKey);
  late final _url = TextEditingController(text: _ai.baseUrlOverride);
  late final _model = TextEditingController(text: _ai.modelOverride);

  bool _obscure = true;
  bool _advanced = false;
  _TestState _test = _TestState.idle;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _advanced = _ai.baseUrlOverride.isNotEmpty || _ai.modelOverride.isNotEmpty;
  }

  @override
  void dispose() {
    _key.dispose();
    _url.dispose();
    _model.dispose();
    super.dispose();
  }

  AiConfig get _draft => AiConfig(
    apiKey: _key.text.trim().isNotEmpty
        ? _key.text.trim()
        : AppConstants.apiKey,
    baseUrl: _url.text.trim().isNotEmpty
        ? _url.text.trim()
        : AppConstants.apiBaseUrl,
    model: _model.text.trim().isNotEmpty
        ? _model.text.trim()
        : AppConstants.aiModel,
  );

  /// ว่าง = ใช้ค่าเริ่มต้น; ต้องเป็น https เพื่อไม่ส่ง key ไปแบบไม่เข้ารหัส
  String? _validateUrl(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    return ApiService.validateBaseUrl(s);
  }

  Future<void> _save() async {
    final urlError = _validateUrl(_url.text);
    if (urlError != null) {
      setState(() => _advanced = true);
      return;
    }
    FocusScope.of(context).unfocus();
    final ok = await _ai.save(
      apiKey: _key.text,
      baseUrl: _url.text,
      model: _model.text,
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (!ok) {
      // ไม่แจ้งว่าบันทึกแล้วเมื่อเขียนลงที่เก็บแบบเข้ารหัสไม่สำเร็จ
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'บันทึกไม่สำเร็จ (ที่เก็บข้อมูลแบบเข้ารหัสของเครื่องใช้งานไม่ได้) กรุณาลองใหม่',
          ),
        ),
      );
      return;
    }
    AppScope.read(context).settings.light();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _ai.lastTest?.ok == true
              ? 'บันทึกการตั้งค่า AI แล้ว (ทดสอบการเชื่อมต่อผ่านแล้ว)'
              : 'บันทึกการตั้งค่า AI แล้ว (ยังไม่ได้ทดสอบการเชื่อมต่อ)',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _runTest() async {
    if (_validateUrl(_url.text) != null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _test = _TestState.running;
      _testMessage = null;
    });
    final draft = _draft;
    try {
      final trace = await AppScope.read(context).api.testConnection(draft);
      await _ai.recordTest(draft, ok: true);
      if (!mounted) return;
      setState(() {
        _test = _TestState.ok;
        _testMessage =
            'เชื่อมต่อสำเร็จ พร้อมใช้งาน (ตอบกลับใน ${(trace.durationMs / 1000).toStringAsFixed(1)} วินาที)';
      });
    } on RecognitionException catch (e) {
      await _ai.recordTest(draft, ok: false, errorType: e.type.name);
      if (!mounted) return;
      setState(() {
        _test = _TestState.failed;
        _testMessage = e.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _test = _TestState.failed;
        _testMessage = 'เชื่อมต่อไม่สำเร็จ กรุณาตรวจสอบการตั้งค่า';
      });
    }
  }

  Future<void> _clearKey() async {
    final ok = await _ai.clearKey();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบ key ไม่สำเร็จ กรุณาลองใหม่')),
      );
      return;
    }
    setState(() {
      _key.clear();
      _test = _TestState.idle;
      _testMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    final ai = AppScope.of(context).ai;
    final hasBuiltIn = ai.hasBuiltInKey;
    final last = ai.lastTest;

    return Scaffold(
      appBar: AppBar(title: const Text('การเชื่อมต่อ AI')),
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
              Panel(
                color: p.surfaceAlt,
                padding: const EdgeInsets.all(Space.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, color: p.accent),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(
                        'แอปใช้ AI เพื่อดูรูปวัตถุดิบและคิดเมนูเพิ่มเติม '
                        'รองรับบริการแบบ OpenAI-compatible (เช่น GenAI ของมหาวิทยาลัย) '
                        'สูตรในแอปและการเลือกวัตถุดิบเองใช้ได้โดยไม่ต้องตั้งค่า',
                        style: t.bodySmall!.copyWith(color: p.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.md),
              Panel(
                padding: const EdgeInsets.all(Space.md),
                child: Row(
                  children: [
                    Icon(
                      ai.keySource == KeySource.none
                          ? Icons.key_off_outlined
                          : last?.ok == false
                          ? Icons.error_outline
                          : Icons.verified_outlined,
                      color: ai.keySource == KeySource.none || last?.ok == false
                          ? p.error
                          : p.success,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('สถานะตอนนี้', style: t.labelLarge),
                          Text(ai.keySource.label, style: t.bodySmall),
                          Text(
                            last == null
                                ? 'ยังไม่ได้ทดสอบการตั้งค่าชุดนี้'
                                : last.ok
                                ? 'ทดสอบล่าสุด: สำเร็จ'
                                : 'ทดสอบล่าสุด: ไม่สำเร็จ',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xl),
              const SectionHeading('API key'),
              TextField(
                controller: _key,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() => _test = _TestState.idle),
                decoration: InputDecoration(
                  hintText: hasBuiltIn
                      ? 'เว้นว่างเพื่อใช้ key ที่ติดมากับแอป'
                      : 'วาง API key ที่นี่',
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'แสดง key' : 'ซ่อน key',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                'key ถูกเก็บแบบเข้ารหัสในเครื่องนี้เท่านั้น และส่งไปยังบริการ AI ที่ระบุด้านล่างเมื่อสแกน',
                style: t.bodySmall,
              ),
              if (_ai.hasUserKey)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _clearKey,
                    icon: Icon(Icons.delete_outline, color: p.error, size: 18),
                    label: Text(
                      'ลบ key ที่บันทึกไว้',
                      style: TextStyle(color: p.error),
                    ),
                  ),
                ),
              const SizedBox(height: Space.lg),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _advanced,
                  onExpansionChanged: (v) => setState(() => _advanced = v),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text('ตั้งค่าขั้นสูง', style: t.titleSmall),
                  subtitle: Text('Base URL และชื่อโมเดล', style: t.bodySmall),
                  children: [
                    TextFormField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: _validateUrl,
                      onChanged: (_) => setState(() => _test = _TestState.idle),
                      decoration: InputDecoration(
                        labelText: 'Base URL',
                        hintText: AppConstants.apiBaseUrl,
                        prefixIcon: const Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    TextField(
                      controller: _model,
                      autocorrect: false,
                      onChanged: (_) => setState(() => _test = _TestState.idle),
                      decoration: InputDecoration(
                        labelText: 'โมเดล (ต้องรองรับรูปภาพ)',
                        hintText: AppConstants.aiModel,
                        prefixIcon: const Icon(Icons.memory),
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'เว้นว่างเพื่อใช้ค่าเริ่มต้น',
                        style: t.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xl),
              if (_testMessage != null) ...[
                _TestResult(ok: _test == _TestState.ok, message: _testMessage!),
                const SizedBox(height: Space.md),
              ],
              OutlinedButton.icon(
                onPressed: _test == _TestState.running || !_draft.hasKey
                    ? null
                    : _runTest,
                icon: _test == _TestState.running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(
                  _test == _TestState.running
                      ? 'กำลังทดสอบ…'
                      : 'ทดสอบการเชื่อมต่อ',
                ),
              ),
              const SizedBox(height: Space.sm),
              FilledButton(onPressed: _save, child: const Text('บันทึก')),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestResult extends StatelessWidget {
  final bool ok;
  final String message;

  const _TestResult({required this.ok, required this.message});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = ok ? p.success : p.error;
    return Panel(
      color: Color.alphaBlend(color.withValues(alpha: 0.1), p.surface),
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error_outline, color: color),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              message,
              style: context.text.bodyMedium!.copyWith(color: p.ink),
            ),
          ),
        ],
      ),
    );
  }
}
