import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cooking_conditions.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'settings.themeMode';
  static const _hapticsKey = 'settings.haptics';
  static const _onboardingKey = 'settings.onboardingDone';
  static const _kitchenKey = 'settings.kitchen';
  static const _demoKey = 'settings.demoMode';
  static const _conditionsKey = 'settings.conditions';

  /// ค่าเริ่มต้นของ "ของพื้นฐานในครัว" — แสดงให้ผู้ใช้เห็นและแก้ได้เสมอ
  static const defaultKitchen = {
    'oil',
    'fish_sauce',
    'soy_sauce',
    'sugar',
    'salt',
    'water',
  };

  ThemeMode get themeMode {
    switch (_prefs.getString(_themeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<bool> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeKey, mode.name);

  bool get haptics => _prefs.getBool(_hapticsKey) ?? true;
  Future<bool> setHaptics(bool value) => _prefs.setBool(_hapticsKey, value);

  bool get onboardingDone => _prefs.getBool(_onboardingKey) ?? false;
  Future<bool> setOnboardingDone(bool value) =>
      _prefs.setBool(_onboardingKey, value);

  Set<String> get kitchen {
    final list = _prefs.getStringList(_kitchenKey);
    return list == null ? {...defaultKitchen} : list.toSet();
  }

  Future<bool> setKitchen(Set<String> ids) =>
      _prefs.setStringList(_kitchenKey, ids.toList()..sort());

  bool get demoMode => _prefs.getBool(_demoKey) ?? false;
  Future<bool> setDemoMode(bool v) => _prefs.setBool(_demoKey, v);

  CookingConditions get conditions {
    final raw = _prefs.getString(_conditionsKey);
    if (raw == null) return CookingConditions.standard;
    try {
      return CookingConditions.fromJson(jsonDecode(raw));
    } catch (_) {
      return CookingConditions.standard;
    }
  }

  Future<bool> setConditions(CookingConditions c) =>
      _prefs.setString(_conditionsKey, jsonEncode(c.toJson()));
}
