import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../data/ai_config_repository.dart';

/// ค่าที่ใช้เรียกบริการ AI ณ ตอนนี้
@immutable
class AiConfig {
  final String apiKey;
  final String baseUrl;
  final String model;

  const AiConfig({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  bool get hasKey => apiKey.isNotEmpty;

  /// ลายนิ้วมือของการตั้งค่า (เก็บแค่ hash 32 บิตของ key ไม่เก็บตัว key)
  /// ใช้ผูกผลทดสอบการเชื่อมต่อกับการตั้งค่าที่ทดสอบจริง
  String get fingerprint {
    var h = 0x811c9dc5;
    for (final b in utf8.encode(apiKey)) {
      h = ((h ^ b) * 0x01000193) & 0xffffffff;
    }
    return '${baseUrl.trim()}|${model.trim()}|${h.toRadixString(16)}';
  }
}

/// แหล่งของ API key ที่ใช้อยู่
enum KeySource {
  user('ใช้ API key ที่คุณใส่ไว้'),
  builtIn('ใช้ API key ที่ติดมากับแอป (ตอน build)'),
  none('ยังไม่ได้ตั้งค่า API key');

  final String label;
  const KeySource(this.label);
}

/// ผลทดสอบการเชื่อมต่อครั้งล่าสุด
class ConnectionTestResult {
  final bool ok;
  final DateTime at;
  final String fingerprint;
  final String? errorType;

  const ConnectionTestResult({
    required this.ok,
    required this.at,
    required this.fingerprint,
    this.errorType,
  });

  String encode() => jsonEncode({
    'ok': ok,
    'at': at.millisecondsSinceEpoch,
    'fp': fingerprint,
    'err': errorType,
  });

  static ConnectionTestResult? decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map;
      return ConnectionTestResult(
        ok: m['ok'] == true,
        at: DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
        fingerprint: m['fp'] as String,
        errorType: m['err'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// การตั้งค่า AI: ผู้ใช้ใส่ key เองได้ (เก็บเข้ารหัส) ถ้าไม่ใส่จะใช้ key ที่ติดมากับแอป (dart-define)
class AiConfigController extends ChangeNotifier {
  AiConfigController(this._repo, {String builtInKey = AppConstants.apiKey})
    : _builtInKey = builtInKey,
      _baseUrl = _repo.baseUrl,
      _model = _repo.model,
      _lastTest = ConnectionTestResult.decode(_repo.lastTest);

  final AiConfigRepository _repo;
  final String _builtInKey;

  String? _userKey;
  String? _baseUrl;
  String? _model;
  ConnectionTestResult? _lastTest;

  /// โหลด key จาก secure storage (เรียกครั้งเดียวตอนเปิดแอป)
  Future<void> load() async {
    _userKey = await _repo.readApiKey();
    notifyListeners();
  }

  bool get hasBuiltInKey => _builtInKey.isNotEmpty;

  bool get hasUserKey => (_userKey ?? '').isNotEmpty;
  String get userKey => _userKey ?? '';
  String get baseUrlOverride => _baseUrl ?? '';
  String get modelOverride => _model ?? '';

  KeySource get keySource => hasUserKey
      ? KeySource.user
      : hasBuiltInKey
      ? KeySource.builtIn
      : KeySource.none;

  AiConfig get config => AiConfig(
    apiKey: hasUserKey ? _userKey! : _builtInKey,
    baseUrl: (_baseUrl ?? '').isNotEmpty ? _baseUrl! : AppConstants.apiBaseUrl,
    model: (_model ?? '').isNotEmpty ? _model! : AppConstants.aiModel,
  );

  bool get hasKey => config.hasKey;

  /// ผลทดสอบล่าสุด เฉพาะเมื่อยังเป็นการตั้งค่าชุดเดียวกับที่ทดสอบ
  ConnectionTestResult? get lastTest {
    final t = _lastTest;
    if (t == null || t.fingerprint != config.fingerprint) return null;
    return t;
  }

  Future<void> recordTest(
    AiConfig tested, {
    required bool ok,
    String? errorType,
  }) async {
    _lastTest = ConnectionTestResult(
      ok: ok,
      at: DateTime.now(),
      fingerprint: tested.fingerprint,
      errorType: errorType,
    );
    notifyListeners();
    try {
      await _repo.setLastTest(_lastTest!.encode());
    } catch (_) {}
  }

  /// บันทึกการตั้งค่า คืน false ถ้าเขียนลงเครื่องไม่สำเร็จ (ค่าในหน่วยความจำไม่เปลี่ยน)
  Future<bool> save({
    required String apiKey,
    required String baseUrl,
    required String model,
  }) async {
    String? clean(String s) => s.trim().isEmpty ? null : s.trim();
    final key = clean(apiKey), url = clean(baseUrl), m = clean(model);
    bool ok;
    try {
      ok =
          await _repo.writeApiKey(key) &&
          await _repo.setBaseUrl(url) &&
          await _repo.setModel(m);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AiConfigController.save failed: ${e.runtimeType}');
      }
      ok = false;
    }
    if (!ok) return false;
    _userKey = key;
    _baseUrl = url;
    _model = m;
    notifyListeners();
    return true;
  }

  Future<bool> setApiKey(String apiKey) =>
      save(apiKey: apiKey, baseUrl: baseUrlOverride, model: modelOverride);

  Future<bool> clearKey() async {
    final ok = await _repo.writeApiKey(null);
    if (!ok) return false;
    _userKey = null;
    notifyListeners();
    return true;
  }
}
