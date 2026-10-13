import '../data/catalog/ingredients_catalog.dart';
import 'cooking_conditions.dart';
import 'ingredient.dart';

enum Difficulty {
  easy('ง่าย'),
  medium('ปานกลาง'),
  hard('ยาก');

  final String label;
  const Difficulty(this.label);

  static Difficulty parse(Object? raw) {
    final s = raw?.toString().toLowerCase().trim() ?? '';
    for (final d in values) {
      if (d.name == s || d.label == s) return d;
    }
    if (s.contains('ยาก') || s == 'difficult') return hard;
    if (s.contains('กลาง') || s == 'normal') return medium;
    return easy;
  }
}

enum RecipeCategory {
  main('จานหลัก', '🍛'),
  soup('ต้ม แกง ซุป', '🍲'),
  salad('ยำ สลัด', '🥗'),
  noodle('เส้น', '🍜'),
  breakfast('อาหารเช้า ของว่าง', '🍳'),
  dessert('ของหวาน', '🍮');

  final String label;
  final String emoji;
  const RecipeCategory(this.label, this.emoji);

  static RecipeCategory parse(Object? raw) {
    final s = raw?.toString().toLowerCase().trim() ?? '';
    for (final c in values) {
      if (c.name == s || c.label == s) return c;
    }
    return main;
  }
}

enum RecipeTag {
  vegetarian('มังสวิรัติ'),
  spicy('เผ็ด'),
  noStove('ไม่ใช้เตา'),
  northern('อาหารเหนือ'),
  isan('อาหารอีสาน'),
  kids('เด็กทานได้');

  final String label;
  const RecipeTag(this.label);
}

/// ส่วนผสมหนึ่งรายการของสูตร พร้อมปริมาณ
class RecipeIngredient {
  /// id ในฐานข้อมูลวัตถุดิบ (null = ส่วนผสมที่ไม่อยู่ในฐานข้อมูล เช่น "ก้อนแกงกะหรี่")
  final String? ingredientId;
  final String name;

  /// ปริมาณสำหรับ [Recipe.servings] ที่ (null = "ตามชอบ")
  final double? amount;
  final String? unit;
  final bool optional;

  const RecipeIngredient(
    this.name, {
    this.ingredientId,
    this.amount,
    this.unit,
    this.optional = false,
  });

  Ingredient? get catalog =>
      ingredientId == null ? null : findIngredient(ingredientId!);

  /// เครื่องปรุงพื้นฐาน (ถือว่ามีในครัว)
  bool get isPantry => catalog?.pantry ?? false;

  String? get emoji => catalog?.emoji;

  /// ปริมาณที่ปรับตามจำนวนที่ เช่น "2 ฟอง", "½ ถ้วย", "ตามชอบ"
  String amountLabel([double factor = 1]) {
    final a = amount;
    if (a == null) return unit ?? 'ตามชอบ';
    final v = formatAmount(a * factor);
    return unit == null || unit!.isEmpty ? v : '$v $unit';
  }

  Map<String, dynamic> toJson() => {
    'id': ingredientId,
    'name': name,
    'amount': amount,
    'unit': unit,
    'optional': optional,
  };

  /// รองรับทั้งรูปแบบใหม่ (object) และแบบเก่า (ชื่อเป็น string)
  static RecipeIngredient fromJson(Object? json) {
    if (json is Map) {
      final name = json['name']?.toString().trim() ?? '';
      final id = json['id']?.toString();
      final amount = json['amount'];
      return RecipeIngredient(
        name,
        ingredientId: (id != null && findIngredient(id) != null)
            ? id
            : IngredientCatalog.resolve(name)?.id,
        amount: amount is num ? amount.toDouble() : double.tryParse('$amount'),
        unit: (json['unit']?.toString().trim().isEmpty ?? true)
            ? null
            : json['unit'].toString().trim(),
        optional: json['optional'] == true,
      );
    }
    final name = json?.toString().trim() ?? '';
    return RecipeIngredient(
      name,
      ingredientId: IngredientCatalog.resolve(name)?.id,
    );
  }
}

/// แสดงตัวเลขปริมาณแบบอ่านง่าย: 0.5 → ½, 1.5 → 1½, 2.0 → 2, 0.33 → ⅓
String formatAmount(double v) {
  if (v <= 0) return '0';
  final whole = v.floor();
  final frac = v - whole;
  const fractions = [
    (0.25, '¼'),
    (0.33, '⅓'),
    (0.5, '½'),
    (0.67, '⅔'),
    (0.75, '¾'),
  ];
  for (final (value, glyph) in fractions) {
    if ((frac - value).abs() < 0.04) {
      return whole == 0 ? glyph : '$whole$glyph';
    }
  }
  if (frac < 0.04) return '$whole';
  if (frac > 0.96) return '${whole + 1}';
  return v.toStringAsFixed(1);
}

class Recipe {
  final String id;
  final String nameTh;

  /// วัตถุดิบหลักของเมนู (ใช้เลือกภาพปก/จัดอันดับ) — สูตร AI อาจเป็นค่าว่าง
  final String primaryIngredientId;
  final String description;

  /// ส่วนผสมทั้งหมดของสูตร (รวมวัตถุดิบหลัก)
  final List<RecipeIngredient> ingredients;
  final List<String> steps;

  final int prepMinutes;
  final int cookMinutes;
  final Difficulty difficulty;
  final int servings;
  final int? kcalPerServing;
  final RecipeCategory category;
  final Set<RecipeTag> tags;

  /// อุปกรณ์หลักที่ขั้นตอนต้องใช้ — null = ไม่ทราบ (เช่น AI ไม่ได้ระบุ)
  final Set<Equipment>? equipment;

  /// สำหรับสูตร AI: true/false ตามที่ AI ระบุ, null = ไม่ทราบ
  /// สูตรในแอปใช้แท็ก [RecipeTag.spicy] ที่ผู้จัดทำกำหนดไว้
  final bool? spicyFlag;

  /// false = ไม่ทราบเวลาที่ใช้ (AI ไม่ได้ระบุ)
  final bool timeKnown;

  /// true = สูตรที่ AI สร้างขึ้น (ไม่ได้มาจากฐานข้อมูลในแอป)
  final bool isAiGenerated;

  const Recipe({
    required this.id,
    required this.nameTh,
    required this.primaryIngredientId,
    required this.ingredients,
    required this.steps,
    this.description = '',
    this.prepMinutes = 10,
    this.cookMinutes = 10,
    this.difficulty = Difficulty.easy,
    this.servings = 2,
    this.kcalPerServing,
    this.category = RecipeCategory.main,
    this.tags = const {},
    this.equipment,
    this.spicyFlag,
    this.timeKnown = true,
    this.isAiGenerated = false,
  });

  int get totalMinutes => prepMinutes + cookMinutes;

  /// เผ็ดหรือไม่ (null = ไม่ทราบ)
  bool? get isSpicy => isAiGenerated ? spicyFlag : has(RecipeTag.spicy);

  /// ป้ายแหล่งที่มาของสูตร
  String get sourceLabel => isAiGenerated ? 'สูตรจาก AI' : 'สูตรในแอป';

  /// emoji ของวัตถุดิบหลัก (ใช้บนภาพปก)
  String get heroEmoji {
    final primary = findIngredient(primaryIngredientId)?.emoji;
    if (primary != null) return primary;
    for (final i in ingredients) {
      final e = i.catalog;
      if (e != null && !e.pantry) return e.emoji;
    }
    return category.emoji;
  }

  bool has(RecipeTag tag) => tags.contains(tag);

  /// กุญแจเฉพาะของสูตร (ใช้กับเมนูโปรด)
  /// สูตร AI รุ่นแรกมี id ซ้ำกันข้ามครั้ง ("AI-1") จึงใช้ชื่อเมนูแทนสำหรับข้อมูลเก่า
  String get favoriteKey =>
      isAiGenerated && id.startsWith('AI-') ? 'ai:$nameTh' : id;

  Map<String, dynamic> toJson() => {
    'v': 2,
    'id': id,
    'nameTh': nameTh,
    'primaryIngredientId': primaryIngredientId,
    'description': description,
    'ingredients': [for (final i in ingredients) i.toJson()],
    'steps': steps,
    'prepMinutes': prepMinutes,
    'cookMinutes': cookMinutes,
    'difficulty': difficulty.name,
    'servings': servings,
    'kcalPerServing': kcalPerServing,
    'category': category.name,
    'tags': [for (final t in tags) t.name],
    'equipment': equipment == null
        ? null
        : [for (final e in equipment!) e.name],
    'spicy': spicyFlag,
    'timeKnown': timeKnown,
    'isAiGenerated': isAiGenerated,
  };
}

int _int(Object? v, int fallback) {
  if (v is num) return v.round();
  return int.tryParse('$v') ?? fallback;
}

/// อ่านสูตรจาก JSON รองรับข้อมูลรุ่นเก่า (v1: ส่วนผสมเป็นรายการชื่อ ไม่รวมวัตถุดิบหลัก)
Recipe recipeFromJson(Map<String, dynamic> json) {
  final isV1 = json['v'] == null;
  final isAi = json['isAiGenerated'] as bool? ?? false;
  final primaryId = json['primaryIngredientId'] as String? ?? '';
  final ingredients = [
    for (final i in (json['ingredients'] as List)) RecipeIngredient.fromJson(i),
  ];
  // สูตรในแอปรุ่นเก่าไม่ได้ใส่วัตถุดิบหลักไว้ในส่วนผสม
  final primary = findIngredient(primaryId);
  if (isV1 && !isAi && primary != null) {
    ingredients.insert(
      0,
      RecipeIngredient(primary.nameTh, ingredientId: primary.id),
    );
  }
  final tags = <RecipeTag>{
    for (final t in (json['tags'] as List? ?? const []))
      for (final tag in RecipeTag.values)
        if (tag.name == t) tag,
  };
  final kcal = json['kcalPerServing'];
  final eq = json['equipment'];
  final spicy = json['spicy'];
  return Recipe(
    id: json['id'] as String,
    nameTh: json['nameTh'] as String,
    primaryIngredientId: primaryId,
    description: json['description'] as String? ?? '',
    ingredients: ingredients,
    steps: List<String>.from(json['steps'] as List),
    prepMinutes: _int(json['prepMinutes'], 10),
    cookMinutes: _int(json['cookMinutes'], 10),
    difficulty: Difficulty.parse(json['difficulty']),
    servings: _int(json['servings'], 2).clamp(1, 20),
    kcalPerServing: kcal == null ? null : _int(kcal, 0),
    category: RecipeCategory.parse(json['category']),
    tags: tags,
    // ค่าที่อ่านไม่ได้ = ไม่ทราบอุปกรณ์ (ไม่ทิ้งเงียบ ๆ จนดูเหมือนข้อมูลครบ)
    equipment: eq is List && eq.every((e) => Equipment.parse(e) != null)
        ? {for (final e in eq) Equipment.parse(e)!}
        : null,
    spicyFlag: spicy is bool ? spicy : null,
    timeKnown: json['timeKnown'] as bool? ?? true,
    isAiGenerated: isAi,
  );
}
