import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';

import '../data/settings_repository.dart';
import '../models/cooking_conditions.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repo)
    : _themeMode = _repo.themeMode,
      _haptics = _repo.haptics,
      _onboardingDone = _repo.onboardingDone,
      _kitchen = _repo.kitchen,
      _demoMode = _repo.demoMode,
      _conditions = _repo.conditions;

  final SettingsRepository _repo;

  ThemeMode _themeMode;
  bool _haptics;
  bool _onboardingDone;
  Set<String> _kitchen;
  bool _demoMode;
  CookingConditions _conditions;

  ThemeMode get themeMode => _themeMode;
  bool get hapticsEnabled => _haptics;
  bool get onboardingDone => _onboardingDone;

  /// ของพื้นฐานในครัวที่ผู้ใช้เลือกว่ามี (ค่าเริ่มต้นสำหรับการสแกนครั้งถัดไป)
  Set<String> get kitchen => Set.unmodifiable(_kitchen);

  /// แสดงข้อมูลทางเทคนิค (trace) ในหน้าสรุปการวิเคราะห์
  bool get demoMode => _demoMode;

  /// เงื่อนไขการทำอาหารที่ใช้ล่าสุด (ค่าเริ่มต้นของการสแกนใหม่)
  CookingConditions get conditions => _conditions;

  Future<bool> _write(Future<bool> Function() op, String what) async {
    try {
      final ok = await op();
      if (!ok && kDebugMode) debugPrint('Settings save $what returned false');
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('Settings save $what failed: $e');
      return false;
    }
  }

  Future<bool> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return true;
    _themeMode = mode;
    notifyListeners();
    return _write(() => _repo.setThemeMode(mode), 'theme');
  }

  Future<bool> setHaptics(bool value) async {
    if (value == _haptics) return true;
    _haptics = value;
    notifyListeners();
    return _write(() => _repo.setHaptics(value), 'haptics');
  }

  Future<bool> completeOnboarding() async {
    _onboardingDone = true;
    notifyListeners();
    return _write(() => _repo.setOnboardingDone(true), 'onboarding');
  }

  Future<bool> setKitchen(Set<String> ids) async {
    _kitchen = {...ids};
    notifyListeners();
    return _write(() => _repo.setKitchen(_kitchen), 'kitchen');
  }

  Future<bool> setDemoMode(bool v) async {
    if (v == _demoMode) return true;
    _demoMode = v;
    notifyListeners();
    return _write(() => _repo.setDemoMode(v), 'demo');
  }

  Future<bool> setConditions(CookingConditions c) async {
    if (c == _conditions) return true;
    _conditions = c;
    notifyListeners();
    return _write(() => _repo.setConditions(c), 'conditions');
  }

  // ---- Haptics (เคารพค่าตั้งค่า) ----
  void selection() {
    if (_haptics) HapticFeedback.selectionClick();
  }

  void light() {
    if (_haptics) HapticFeedback.lightImpact();
  }

  void medium() {
    if (_haptics) HapticFeedback.mediumImpact();
  }
}
