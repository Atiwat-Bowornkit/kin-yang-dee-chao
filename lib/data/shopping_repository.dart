import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shopping_item.dart';

class ShoppingRepository {
  ShoppingRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'shopping.v1';

  List<ShoppingItem> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final out = <ShoppingItem>[];
      for (final item in list) {
        try {
          out.add(
            ShoppingItem.fromJson(Map<String, dynamic>.from(item as Map)),
          );
        } catch (_) {}
      }
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('ShoppingRepository.load failed: $e');
      return [];
    }
  }

  /// คืน false เมื่อเขียนลงเครื่องไม่สำเร็จ
  Future<bool> save(List<ShoppingItem> items) =>
      _prefs.setString(_key, jsonEncode([for (final i in items) i.toJson()]));
}
