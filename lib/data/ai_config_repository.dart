import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ที่เก็บข้อมูลลับ (API key) — แยก interface เพื่อให้ทดสอบได้โดยไม่ต้องใช้ platform channel
abstract class SecretStore {
  Future<String?> read(String key);

  /// คืน false เมื่อเขียนไม่สำเร็จ (เช่น Keystore ใช้งานไม่ได้)
  Future<bool> write(String key, String? value);
}

/// เก็บแบบเข้ารหัสด้วย Android Keystore / iOS Keychain
class SecureSecretStore implements SecretStore {
  const SecureSecretStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureSecretStore.read failed: ${e.runtimeType}');
      }
      return null;
    }
  }

  @override
  Future<bool> write(String key, String? value) async {
    try {
      if (value == null || value.isEmpty) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
      return true;
    } catch (e) {
      // ไม่ log ค่า key
      if (kDebugMode) {
        debugPrint('SecureSecretStore.write failed: ${e.runtimeType}');
      }
      return false;
    }
  }
}

/// เก็บในหน่วยความจำ (ใช้ในเทสต์)
class MemorySecretStore implements SecretStore {
  MemorySecretStore([Map<String, String>? initial]) : _data = {...?initial};

  final Map<String, String> _data;

  /// ใช้ในเทสต์จำลองการเขียนไม่สำเร็จ
  bool failWrites = false;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<bool> write(String key, String? value) async {
    if (failWrites) return false;
    if (value == null || value.isEmpty) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
    return true;
  }
}

/// การตั้งค่าบริการ AI: key อยู่ใน [SecretStore], URL/โมเดลอยู่ใน SharedPreferences
class AiConfigRepository {
  AiConfigRepository(this._prefs, this._secrets);

  final SharedPreferences _prefs;
  final SecretStore _secrets;

  static const _apiKey = 'ai.apiKey';
  static const _baseUrlKey = 'ai.baseUrl';
  static const _modelKey = 'ai.model';

  static const _lastTestKey = 'ai.lastTest';

  Future<String?> readApiKey() => _secrets.read(_apiKey);
  Future<bool> writeApiKey(String? value) => _secrets.write(_apiKey, value);

  String? get baseUrl => _prefs.getString(_baseUrlKey);
  Future<bool> setBaseUrl(String? v) => v == null || v.isEmpty
      ? _prefs.remove(_baseUrlKey)
      : _prefs.setString(_baseUrlKey, v);

  String? get model => _prefs.getString(_modelKey);
  Future<bool> setModel(String? v) => v == null || v.isEmpty
      ? _prefs.remove(_modelKey)
      : _prefs.setString(_modelKey, v);

  /// ผลทดสอบการเชื่อมต่อล่าสุด (เก็บ fingerprint ของการตั้งค่า ไม่เก็บ key)
  String? get lastTest => _prefs.getString(_lastTestKey);
  Future<bool> setLastTest(String? v) => v == null
      ? _prefs.remove(_lastTestKey)
      : _prefs.setString(_lastTestKey, v);
}
