import '../models/ingredient.dart';
import '../models/recipe.dart';
import 'catalog/ingredients_catalog.dart';
import 'catalog/recipes_catalog.dart';

/// ตัวกรองรายการสูตร (หน้า "สูตรทั้งหมด"/ค้นหา)
class RecipeFilter {
  final RecipeCategory? category;
  final int? maxMinutes;
  final Difficulty? difficulty;
  final bool vegetarian;
  final bool notSpicy;
  final bool noStove;

  const RecipeFilter({
    this.category,
    this.maxMinutes,
    this.difficulty,
    this.vegetarian = false,
    this.notSpicy = false,
    this.noStove = false,
  });

  static const none = RecipeFilter();

  bool get isEmpty =>
      category == null &&
      maxMinutes == null &&
      difficulty == null &&
      !vegetarian &&
      !notSpicy &&
      !noStove;

  bool accepts(Recipe r) {
    if (category != null && r.category != category) return false;
    if (maxMinutes != null && r.totalMinutes > maxMinutes!) return false;
    if (difficulty != null && r.difficulty != difficulty) return false;
    if (vegetarian && !r.has(RecipeTag.vegetarian)) return false;
    if (notSpicy && r.has(RecipeTag.spicy)) return false;
    if (noStove && !r.has(RecipeTag.noStove)) return false;
    return true;
  }

  RecipeFilter copyWith({
    Object? category = _keep,
    Object? maxMinutes = _keep,
    Object? difficulty = _keep,
    bool? vegetarian,
    bool? notSpicy,
    bool? noStove,
  }) => RecipeFilter(
    category: category == _keep ? this.category : category as RecipeCategory?,
    maxMinutes: maxMinutes == _keep ? this.maxMinutes : maxMinutes as int?,
    difficulty: difficulty == _keep
        ? this.difficulty
        : difficulty as Difficulty?,
    vegetarian: vegetarian ?? this.vegetarian,
    notSpicy: notSpicy ?? this.notSpicy,
    noStove: noStove ?? this.noStove,
  );
}

const _keep = Object();

/// ฐานข้อมูลเมนูภายในแอปและการจับคู่กับวัตถุดิบที่ผู้ใช้มี
class RecipeRepository {
  const RecipeRepository();

  static List<Recipe> get recipes => recipesCatalog;

  static final Map<String, Recipe> _byId = {
    for (final r in recipesCatalog) r.id: r,
  };

  static Recipe? byId(String id) => _byId[id];

  /// รายการสูตรตามตัวกรอง (เรียงตามเวลาที่ใช้ แล้วตามชื่อ)
  List<Recipe> browse([RecipeFilter filter = RecipeFilter.none]) {
    final list = [
      for (final r in recipes)
        if (filter.accepts(r)) r,
    ];
    list.sort((a, b) {
      final t = a.totalMinutes.compareTo(b.totalMinutes);
      return t != 0 ? t : a.nameTh.compareTo(b.nameTh);
    });
    return list;
  }

  /// "เมนูแนะนำวันนี้": สุ่มแบบคงที่ตามวัน (เปิดแอปวันเดียวกันได้ชุดเดิม)
  List<Recipe> dailyPicks({int count = 6, DateTime? now}) {
    final d = now ?? DateTime.now();
    final seed = d.year * 1000 + d.month * 40 + d.day;
    final list = [...recipes];
    // LCG ง่าย ๆ แทน Random เพื่อให้ผลคงที่ข้ามแพลตฟอร์ม
    var x = seed;
    for (var i = list.length - 1; i > 0; i--) {
      x = (x * 1103515245 + 12345) & 0x7fffffff;
      final j = x % (i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
    return list.take(count).toList();
  }

  /// ค้นหาเมนูจากชื่อเมนูหรือชื่อส่วนผสม (ไม่สนตัวพิมพ์/ช่องว่าง)
  List<RecipeMatch> search(
    String query, {
    RecipeFilter filter = RecipeFilter.none,
  }) {
    final q = IngredientCatalog.normalize(query);
    if (q.isEmpty) return const [];
    // คำค้นที่ตรงกับวัตถุดิบในฐานข้อมูล → หาด้วย id ด้วย (เช่น "หมูสับ" เจอสูตรที่ใช้ "หมู")
    final ingredient = IngredientCatalog.resolve(query);
    final byName = <RecipeMatch>[];
    final byIngredient = <RecipeMatch>[];
    for (final recipe in recipes) {
      if (!filter.accepts(recipe)) continue;
      final inName = IngredientCatalog.normalize(recipe.nameTh).contains(q);
      final inIngredients = recipe.ingredients.any(
        (i) =>
            (ingredient != null && i.ingredientId == ingredient.id) ||
            IngredientCatalog.normalize(i.name).contains(q),
      );
      if (inName) {
        byName.add(RecipeMatch.browse(recipe));
      } else if (inIngredients) {
        byIngredient.add(RecipeMatch.browse(recipe));
      }
    }
    return [...byName, ...byIngredient];
  }

  /// หาเมนูจากวัตถุดิบที่ผู้ใช้มี (ยังไม่จัดอันดับตามเงื่อนไข — ดู [rankRecommendations])
  /// แสดงเมนูที่มีวัตถุดิบหลัก หรือมีวัตถุดิบ (ไม่นับเครื่องปรุง) ตั้งแต่ 2 อย่าง
  /// หรือมีครบอย่างน้อยครึ่งหนึ่งของที่ต้องใช้
  /// [kitchen] = id ของเครื่องปรุงพื้นฐานที่ผู้ใช้ยืนยันว่ามี
  List<RecipeMatch> matchRecipes(
    List<DetectedIngredient> owned, {
    Set<String> kitchen = const {},
  }) {
    final pantry = Pantry.from(owned, kitchen: kitchen);
    if (pantry.isEmpty) return const [];
    final out = <RecipeMatch>[];
    for (final recipe in recipes) {
      final m = RecipeMatch.compute(recipe, pantry);
      if (m.haveCore.isEmpty) continue;
      final primaryHeld = pantry.holdsId(recipe.primaryIngredientId);
      if (!primaryHeld && m.haveCore.length < 2 && m.coverage < 0.5) continue;
      out.add(m);
    }
    return out;
  }
}

/// วัตถุดิบที่ผู้ใช้มี (เทียบด้วย id ในฐานข้อมูล หรือชื่อที่ normalize แล้ว)
/// แยก [ids] (วัตถุดิบที่ยืนยัน) กับ [kitchen] (ของพื้นฐานในครัวที่ผู้ใช้เลือกว่ามี)
class Pantry {
  final Set<String> ids;
  final Set<String> names;
  final Set<String> kitchen;

  const Pantry(this.ids, this.names, [this.kitchen = const {}]);

  factory Pantry.from(
    List<DetectedIngredient> owned, {
    Set<String> kitchen = const {},
  }) {
    final ids = <String>{};
    final names = <String>{};
    for (final o in owned) {
      final c = o.known
          ? findIngredient(o.id)
          : IngredientCatalog.resolve(o.nameTh);
      if (c != null) {
        ids.add(c.id);
      } else {
        names.add(IngredientCatalog.normalize(o.nameTh));
      }
    }
    return Pantry(ids, names, kitchen);
  }

  bool get isEmpty => ids.isEmpty && names.isEmpty;

  bool holdsId(String id) => id.isNotEmpty && ids.contains(id);

  bool holds(RecipeIngredient i) {
    if (i.ingredientId != null) return ids.contains(i.ingredientId);
    return names.contains(IngredientCatalog.normalize(i.name));
  }

  bool inKitchen(RecipeIngredient i) =>
      i.ingredientId != null && kitchen.contains(i.ingredientId);
}

/// ผลจับคู่เมนูกับวัตถุดิบที่มี
/// - [have] ส่วนผสมที่อยู่ในรายการวัตถุดิบที่ผู้ใช้ยืนยัน
/// - [need] ส่วนผสมหลักจำเป็นที่ยังขาด (ต้องเตรียม/ซื้อ)
/// - [optional] ส่วนผสมเสริมที่ไม่มี (ไม่มีก็ทำได้)
/// - [staples] เครื่องปรุงพื้นฐานที่ผู้ใช้เลือกไว้ว่ามีในครัว (ไม่นับเป็นของขาด)
/// - [pantryNeed] เครื่องปรุงพื้นฐานที่ผู้ใช้ไม่ได้เลือกว่ามี (ต้องเตรียม แต่ไม่นับใน x/y)
class RecipeMatch {
  final Recipe recipe;
  final List<RecipeIngredient> have;
  final List<RecipeIngredient> need;
  final List<RecipeIngredient> optional;
  final List<RecipeIngredient> staples;
  final List<RecipeIngredient> pantryNeed;

  /// true = เปิดดูเฉย ๆ (ค้นหา/เมนูโปรด) ไม่ได้มาจากวัตถุดิบที่ผู้ใช้มี
  final bool browsing;

  const RecipeMatch({
    required this.recipe,
    required this.have,
    required this.need,
    this.optional = const [],
    this.staples = const [],
    this.pantryNeed = const [],
    this.browsing = false,
  });

  factory RecipeMatch.compute(Recipe recipe, Pantry pantry) {
    final have = <RecipeIngredient>[];
    final need = <RecipeIngredient>[];
    final optional = <RecipeIngredient>[];
    final staples = <RecipeIngredient>[];
    final pantryNeed = <RecipeIngredient>[];
    for (final i in recipe.ingredients) {
      if (pantry.holds(i)) {
        have.add(i);
      } else if (i.isPantry && pantry.inKitchen(i)) {
        staples.add(i);
      } else if (i.optional) {
        optional.add(i);
      } else if (i.isPantry) {
        pantryNeed.add(i);
      } else {
        need.add(i);
      }
    }
    return RecipeMatch(
      recipe: recipe,
      have: have,
      need: need,
      optional: optional,
      staples: staples,
      pantryNeed: pantryNeed,
    );
  }

  /// มุมมองเมนูแบบ "เปิดดูเฉย ๆ": ไม่มีวัตถุดิบที่ "มีแล้ว" และไม่สมมติว่ามีของในครัว
  factory RecipeMatch.browse(Recipe recipe) {
    final m = RecipeMatch.compute(recipe, const Pantry({}, {}));
    return RecipeMatch(
      recipe: recipe,
      have: const [],
      need: m.need,
      optional: m.optional,
      pantryNeed: m.pantryNeed,
      browsing: true,
    );
  }

  /// วัตถุดิบหลักจำเป็นที่มี (ไม่นับเครื่องปรุงพื้นฐานและของเสริม)
  List<RecipeIngredient> get haveCore => [
    for (final i in have)
      if (!i.isPantry && !i.optional) i,
  ];

  /// จำนวนวัตถุดิบหลักจำเป็นทั้งหมดของสูตร (ตัวหารของ x/y)
  int get coreTotal => haveCore.length + need.length;

  /// สัดส่วนวัตถุดิบหลักจำเป็นที่มีแล้ว — สูตรที่ไม่มีวัตถุดิบหลักเลยถือว่าครบ (ไม่หารด้วยศูนย์)
  double get coverage => coreTotal == 0 ? 1 : haveCore.length / coreTotal;

  /// ของที่ต้องเตรียมเพิ่มก่อนทำ (วัตถุดิบหลัก + เครื่องปรุงที่ไม่ได้เลือกว่ามี)
  List<RecipeIngredient> get toPrepare => [...need, ...pantryNeed];

  List<String> get haveNames => [for (final i in have) i.name];
  List<String> get needNames => [for (final i in need) i.name];
}

/// จับคู่สูตรจาก AI กับวัตถุดิบที่ผู้ใช้มี (ใช้กติกาเดียวกับสูตรในแอป)
RecipeMatch matchAiRecipe(
  Recipe recipe,
  List<DetectedIngredient> owned, {
  Set<String> kitchen = const {},
}) => RecipeMatch.compute(recipe, Pantry.from(owned, kitchen: kitchen));
