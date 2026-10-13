import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/catalog/ingredients_catalog.dart';
import '../data/shopping_repository.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/shopping_item.dart';

/// สถานะของส่วนผสมสูตรหนึ่งในรายการซื้อของ
enum ShoppingSync { absent, outdated, current }

/// ผลเพิ่มของที่พิมพ์เอง
enum AddNameResult { added, revived, duplicate, empty, saveFailed }

/// รายการซื้อของ: เพิ่มจากสูตร (กันซ้ำ) หรือพิมพ์เพิ่มเอง ติ๊ก/ลบ/เลิกทำได้
class ShoppingController extends ChangeNotifier {
  ShoppingController(this._repo) : _items = _repo.load();

  static const _uuid = Uuid();

  final ShoppingRepository _repo;
  final List<ShoppingItem> _items; // ใหม่สุดอยู่ก่อน
  final Map<String, ({ShoppingItem item, int index})> _pending = {};

  /// เพิ่มทุกครั้งที่รายการถูกคืนกลับหลังลบไม่สำเร็จ — UI ใช้ประกอบ key ของ Dismissible
  final Map<String, int> _restores = {};
  int restoreEpoch(String id) => _restores[id] ?? 0;

  List<ShoppingItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get remaining => _items.where((i) => !i.checked).length;
  int get checkedCount => _items.length - remaining;

  /// จัดกลุ่มตามหมวด (ลำดับตาม enum) — ในกลุ่ม: ยังไม่ซื้ออยู่ก่อน
  Map<IngredientCategory, List<ShoppingItem>> get grouped {
    final out = <IngredientCategory, List<ShoppingItem>>{};
    for (final c in IngredientCategory.values) {
      final list = [
        for (final i in _items)
          if (i.category == c) i,
      ];
      if (list.isEmpty) continue;
      list.sort((a, b) => (a.checked ? 1 : 0) - (b.checked ? 1 : 0));
      out[c] = list;
    }
    return out;
  }

  /// คืน false เมื่อบันทึกลงเครื่องไม่สำเร็จ
  Future<bool> _persist() async {
    try {
      return await _repo.save(_items);
    } catch (e) {
      if (kDebugMode) debugPrint('ShoppingController save failed: $e');
      return false;
    }
  }

  int _indexOfKey(String key) => _items.indexWhere((i) => i.key == key);

  /// เพิ่มของที่พิมพ์เอง — แยกผล "ซ้ำ" ออกจาก "บันทึกไม่สำเร็จ"
  Future<AddNameResult> addName(String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return AddNameResult.empty;
    final known = IngredientCatalog.resolve(name);
    final key = known?.id ?? IngredientCatalog.normalize(name);
    final i = _indexOfKey(key);
    var revived = false;
    final before = List<ShoppingItem>.of(_items);
    if (i >= 0) {
      if (!_items[i].checked) return AddNameResult.duplicate;
      _items[i] = _items[i].copyWith(checked: false);
      revived = true;
    } else {
      _items.insert(
        0,
        ShoppingItem(
          id: _uuid.v4(),
          name: known?.nameTh ?? name,
          ingredientId: known?.id,
          createdAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
    if (!await _persist()) {
      // ย้อนกลับ: ไม่ปล่อยรายการที่ไม่ได้บันทึกค้างในหน่วยความจำ (ลองชื่อเดิมซ้ำต้องไม่กลายเป็น "ซ้ำ")
      _items
        ..clear()
        ..addAll(before);
      notifyListeners();
      return AddNameResult.saveFailed;
    }
    return revived ? AddNameResult.revived : AddNameResult.added;
  }

  /// เพิ่มส่วนผสมของสูตร (กันซ้ำด้วย id/ชื่อ)
  /// - ปริมาณเก็บแยกตามสูตร: เพิ่มจากสูตรเดิมซ้ำ = แทนปริมาณเดิม (เช่น เปลี่ยนจำนวนที่)
  /// - หน่วยเดียวกันรวมกัน หน่วยต่างกันแสดงแยก
  /// คืนจำนวนรายการที่เพิ่มใหม่หรือปลุกกลับมา หรือ null ถ้าบันทึกไม่สำเร็จ
  Future<int?> addFromRecipe(
    Recipe recipe,
    Iterable<RecipeIngredient> ingredients, {
    double factor = 1,
  }) async {
    final before = List<ShoppingItem>.of(_items);
    var added = 0;
    for (final ing in ingredients) {
      final key = ing.ingredientId ?? IngredientCatalog.normalize(ing.name);
      final q = ShoppingQuantity(
        amount: ing.amount == null ? null : ing.amount! * factor,
        unit: ing.unit,
        recipe: recipe.nameTh,
      );
      final i = _indexOfKey(key);
      if (i >= 0) {
        final cur = _items[i];
        final recipes = cur.recipes.contains(recipe.nameTh)
            ? cur.recipes
            : [...cur.recipes, recipe.nameTh];
        // รายการที่ซื้อแล้วถูกใช้ไปแล้ว → เริ่มนับปริมาณใหม่
        // เพิ่มสูตรเดิมซ้ำ = แทนที่ปริมาณของสูตรนั้นในตำแหน่งเดิม (ไม่บวกซ้ำ)
        final List<ShoppingQuantity> quantities;
        if (cur.checked) {
          quantities = [q];
          added++;
        } else {
          final at = cur.quantities.indexWhere(
            (x) => x.recipe == recipe.nameTh,
          );
          quantities = [...cur.quantities];
          at >= 0 ? quantities[at] = q : quantities.add(q);
        }
        _items[i] = cur.copyWith(
          checked: false,
          recipes: cur.checked ? [recipe.nameTh] : recipes,
          quantities: quantities,
        );
        continue;
      }
      _items.insert(
        0,
        ShoppingItem(
          id: _uuid.v4(),
          name: ing.catalog?.nameTh ?? ing.name,
          ingredientId: ing.ingredientId,
          quantities: [q],
          recipes: [recipe.nameTh],
          createdAt: DateTime.now(),
        ),
      );
      added++;
    }
    notifyListeners();
    if (await _persist()) return added;
    // บันทึกไม่สำเร็จ: คืนรายการเดิม (ไม่แสดงว่าเพิ่มแล้ว และกดลองใหม่ได้)
    _items
      ..clear()
      ..addAll(before);
    notifyListeners();
    return null;
  }

  /// รายการของสูตรนี้ในรายการซื้อของตรงกับปริมาณที่จะเพิ่มตอนนี้แล้วหรือยัง
  /// (ใช้ตัดสินว่าปุ่มบนหน้าสูตรต้องเพิ่ม/อัปเดต หรือไม่มีอะไรต้องทำ)
  ShoppingSync syncState(
    Recipe recipe,
    RecipeIngredient ing, {
    double factor = 1,
  }) {
    final i = _indexOfKey(
      ing.ingredientId ?? IngredientCatalog.normalize(ing.name),
    );
    if (i < 0 || _items[i].checked) return ShoppingSync.absent;
    final want = ing.amount == null ? null : ing.amount! * factor;
    for (final q in _items[i].quantities) {
      if (q.recipe != recipe.nameTh) continue;
      final sameAmount =
          (q.amount == null && want == null) ||
          (q.amount != null && want != null && (q.amount! - want).abs() < 1e-9);
      return sameAmount && q.unit == ing.unit
          ? ShoppingSync.current
          : ShoppingSync.outdated;
    }
    return ShoppingSync.outdated; // มีของนี้อยู่แล้วแต่ยังไม่มีส่วนของสูตรนี้
  }

  bool contains(RecipeIngredient ing) {
    final key = ing.ingredientId ?? IngredientCatalog.normalize(ing.name);
    final i = _indexOfKey(key);
    return i >= 0 && !_items[i].checked;
  }

  /// ติ๊ก/เอาติ๊กที่ซื้อแล้ว คืน false ถ้าบันทึกลงเครื่องไม่สำเร็จ (สถานะในหน้าจอยังเปลี่ยน)
  Future<bool> toggle(String id) async {
    final i = _items.indexWhere((x) => x.id == id);
    if (i < 0) return true;
    _items[i] = _items[i].copyWith(checked: !_items[i].checked);
    notifyListeners();
    return _persist();
  }

  /// ลบแบบเลิกทำได้ (ส่วน sync ทำก่อน await แรก) — บันทึกไม่สำเร็จ = รายการกลับมาและคืน false
  Future<bool> remove(String id) async {
    final i = _items.indexWhere((x) => x.id == id);
    if (i < 0) return true;
    _pending[id] = (item: _items.removeAt(i), index: i);
    notifyListeners();
    final ok = await _persist();
    if (!ok) {
      final p = _pending.remove(id);
      if (p != null) {
        _restores[id] = restoreEpoch(id) + 1;
        _items.insert(p.index.clamp(0, _items.length), p.item);
        notifyListeners();
      }
    }
    return ok;
  }

  /// เลิกทำการลบ คืน false ถ้าบันทึกกลับลงเครื่องไม่สำเร็จ (รายการยังแสดงในรอบนี้)
  Future<bool> undoRemoval(String id) async {
    final p = _pending.remove(id);
    if (p == null) return true;
    _items.insert(p.index.clamp(0, _items.length), p.item);
    notifyListeners();
    return _persist();
  }

  void finalizeRemoval(String id) => _pending.remove(id);

  /// ลบที่ซื้อแล้ว — บันทึกไม่สำเร็จ = รายการกลับมาและ [saved] เป็น false
  Future<({int removed, bool saved})> clearChecked() async {
    final before = List<ShoppingItem>.of(_items);
    _items.removeWhere((i) => i.checked);
    final removed = before.length - _items.length;
    if (removed == 0) return (removed: 0, saved: true);
    notifyListeners();
    final ok = await _persist();
    if (!ok) {
      _items
        ..clear()
        ..addAll(before);
      notifyListeners();
      return (removed: 0, saved: false);
    }
    return (removed: removed, saved: true);
  }

  /// ล้างทั้งหมด — บันทึกไม่สำเร็จ = รายการกลับมาและคืน false
  Future<bool> clear() async {
    final before = List<ShoppingItem>.of(_items);
    _items.clear();
    final pending = Map.of(_pending);
    _pending.clear();
    notifyListeners();
    final ok = await _persist();
    if (!ok) {
      _items.addAll(before);
      _pending.addAll(pending);
      notifyListeners();
    }
    return ok;
  }

  /// ข้อความสำหรับแชร์ (เฉพาะที่ยังไม่ได้ซื้อ)
  String shareText() {
    final buf = StringBuffer('🛒 รายการซื้อของ\n');
    for (final e in grouped.entries) {
      final todo = e.value.where((i) => !i.checked).toList();
      if (todo.isEmpty) continue;
      buf.writeln('\n${e.key.label}');
      for (final i in todo) {
        buf.writeln('☐ ${i.name}${i.amount == null ? '' : ' (${i.amount})'}');
      }
    }
    buf.write('\n— จากแอป กิ๋นหยังดีจ้าว');
    return buf.toString();
  }
}
