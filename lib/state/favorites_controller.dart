import 'package:flutter/foundation.dart';

import '../data/favorites_repository.dart';
import '../models/recipe.dart';

class FavoritesController extends ChangeNotifier {
  FavoritesController(this._repo) : _recipes = _repo.load();

  final FavoritesRepository _repo;
  final List<Recipe> _recipes; // ที่เพิ่งกดโปรดอยู่ก่อน

  List<Recipe> get recipes => List.unmodifiable(_recipes);
  bool get isEmpty => _recipes.isEmpty;

  bool isFavorite(Recipe recipe) =>
      _recipes.any((r) => r.favoriteKey == recipe.favoriteKey);

  /// true เมื่อการบันทึกครั้งล่าสุดล้มเหลว
  bool lastSaveFailed = false;

  Future<bool> _persist() async {
    var ok = false;
    try {
      ok = await _repo.save(_recipes);
    } catch (e) {
      if (kDebugMode) debugPrint('FavoritesController save failed: $e');
    }
    lastSaveFailed = !ok;
    return ok;
  }

  /// สลับสถานะโปรด คืนสถานะใหม่ ([FavoriteToggle.isFavorite]) แยกจากผลการบันทึก ([FavoriteToggle.saved])
  /// บันทึกไม่สำเร็จ: สถานะในหน่วยความจำยังเปลี่ยน (เขียนครั้งถัดไปจะบันทึกรวมไปด้วย) แต่ UI ต้องบอกผู้ใช้ว่ายังไม่ได้บันทึก
  Future<FavoriteToggle> toggle(Recipe recipe) async {
    final i = _recipes.indexWhere((r) => r.favoriteKey == recipe.favoriteKey);
    final nowFavorite = i < 0;
    if (nowFavorite) {
      _recipes.insert(0, recipe);
    } else {
      _recipes.removeAt(i);
    }
    notifyListeners();
    final saved = await _persist();
    return (isFavorite: nowFavorite, saved: saved);
  }

  /// ล้างทั้งหมด — บันทึกไม่สำเร็จ = รายการกลับมาและคืน false
  Future<bool> clear() async {
    final old = List<Recipe>.of(_recipes);
    _recipes.clear();
    notifyListeners();
    final ok = await _persist();
    if (!ok) {
      _recipes.addAll(old);
      notifyListeners();
    }
    return ok;
  }
}

/// ผลสลับเมนูโปรด: สถานะใหม่ + บันทึกลงเครื่องสำเร็จหรือไม่
typedef FavoriteToggle = ({bool isFavorite, bool saved});
