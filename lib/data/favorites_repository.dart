import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';
import 'recipe_repository.dart';

class FavoritesRepository {
  FavoritesRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'favorites.v1';

  /// สูตรในแอปใช้ข้อมูลล่าสุดจากฐานข้อมูลเสมอ (ไม่ใช้สำเนาเก่าที่บันทึกไว้)
  List<Recipe> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final out = <Recipe>[];
      for (final item in list) {
        try {
          final saved = recipeFromJson(Map<String, dynamic>.from(item as Map));
          final current = saved.isAiGenerated
              ? null
              : RecipeRepository.byId(saved.id);
          out.add(current ?? saved);
        } catch (_) {}
      }
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('FavoritesRepository.load failed: $e');
      return [];
    }
  }

  /// คืน false เมื่อเขียนลงเครื่องไม่สำเร็จ
  Future<bool> save(List<Recipe> recipes) =>
      _prefs.setString(_key, jsonEncode([for (final r in recipes) r.toJson()]));
}
