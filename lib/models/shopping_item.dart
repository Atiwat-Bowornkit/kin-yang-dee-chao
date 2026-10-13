import '../data/catalog/ingredients_catalog.dart';
import 'ingredient.dart';
import 'recipe.dart';

/// ปริมาณหนึ่งก้อนของรายการซื้อของ (มาจากสูตรหนึ่ง หรือข้อความที่พิมพ์เอง)
class ShoppingQuantity {
  final double? amount;
  final String? unit;

  /// ชื่อเมนูที่ต้องใช้ปริมาณนี้ (null = พิมพ์เอง/ข้อมูลเก่า)
  final String? recipe;

  const ShoppingQuantity({this.amount, this.unit, this.recipe});

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'unit': unit,
    'recipe': recipe,
  };

  static ShoppingQuantity? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final a = raw['amount'];
    final u = raw['unit'];
    final r = raw['recipe'];
    return ShoppingQuantity(
      amount: a is num ? a.toDouble() : null,
      unit: u is String && u.isNotEmpty ? u : null,
      recipe: r is String ? r : null,
    );
  }
}

/// รายการซื้อของหนึ่งรายการ
class ShoppingItem {
  final String id;
  final String name;
  final String? ingredientId;

  /// ปริมาณแยกตามสูตร — รวมกันเฉพาะหน่วยเดียวกัน (ไม่แปลงหน่วยต่างชนิด)
  final List<ShoppingQuantity> quantities;

  /// ชื่อเมนูที่ต้องใช้ของชิ้นนี้ (อาจมีหลายเมนู)
  final List<String> recipes;
  final bool checked;
  final DateTime createdAt;

  const ShoppingItem({
    required this.id,
    required this.name,
    required this.createdAt,
    this.ingredientId,
    this.quantities = const [],
    this.recipes = const [],
    this.checked = false,
  });

  Ingredient? get catalog =>
      ingredientId == null ? null : findIngredient(ingredientId!);

  IngredientCategory get category =>
      catalog?.category ?? IngredientCategory.other;

  String? get emoji => catalog?.emoji;

  /// กุญแจกันซ้ำ: id ในฐานข้อมูล หรือชื่อที่ normalize แล้ว
  String get key => ingredientId ?? IngredientCatalog.normalize(name);

  /// ปริมาณรวมสำหรับแสดงผล เช่น "250 กรัม + 1 ช้อนโต๊ะ" (null = ไม่ได้ระบุ)
  String? get amount {
    if (quantities.isEmpty) return null;
    final sums = <String, double>{};
    final order = <String>[];
    final texts = <String>[];
    for (final q in quantities) {
      if (q.amount == null) {
        final t = q.unit ?? 'ตามชอบ';
        if (!texts.contains(t)) texts.add(t);
        continue;
      }
      final u = q.unit ?? '';
      if (!sums.containsKey(u)) order.add(u);
      sums[u] = (sums[u] ?? 0) + q.amount!;
    }
    final parts = [
      for (final u in order)
        u.isEmpty ? formatAmount(sums[u]!) : '${formatAmount(sums[u]!)} $u',
      // ข้อความอย่าง "ตามชอบ" แสดงเฉพาะเมื่อไม่มีปริมาณที่เป็นตัวเลขเลย
      if (order.isEmpty) ...texts,
    ];
    return parts.isEmpty ? null : parts.join(' + ');
  }

  ShoppingItem copyWith({
    bool? checked,
    List<String>? recipes,
    List<ShoppingQuantity>? quantities,
  }) => ShoppingItem(
    id: id,
    name: name,
    createdAt: createdAt,
    ingredientId: ingredientId,
    quantities: quantities ?? this.quantities,
    recipes: recipes ?? this.recipes,
    checked: checked ?? this.checked,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ingredientId': ingredientId,
    'quantities': [for (final q in quantities) q.toJson()],
    'recipes': recipes,
    'checked': checked,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    final quantities = <ShoppingQuantity>[
      for (final q in (json['quantities'] as List? ?? const []))
        ?ShoppingQuantity.fromJson(q),
    ];
    // ข้อมูลรุ่นก่อนเก็บปริมาณเป็นข้อความเดียว → เก็บเป็นข้อความ (ไม่เดาแปลงตัวเลข)
    final legacy = json['amount'];
    if (quantities.isEmpty && legacy is String && legacy.isNotEmpty) {
      quantities.add(ShoppingQuantity(unit: legacy));
    }
    return ShoppingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      ingredientId: json['ingredientId'] as String?,
      quantities: quantities,
      recipes: List<String>.from(json['recipes'] as List? ?? const []),
      checked: json['checked'] as bool? ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int? ?? 0,
      ),
    );
  }
}
