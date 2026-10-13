import '../data/catalog/ingredients_catalog.dart';

/// หมวดของวัตถุดิบ (ใช้จัดกลุ่มในตัวเลือกวัตถุดิบและรายการซื้อของ)
enum IngredientCategory {
  protein('เนื้อสัตว์และโปรตีน'),
  vegetable('ผัก'),
  herb('สมุนไพรและเครื่องเทศ'),
  fruit('ผลไม้'),
  staple('ข้าว เส้น และแป้ง'),
  dairy('นม ไข่ และกะทิ'),
  seasoning('เครื่องปรุง'),
  other('อื่นๆ');

  final String label;
  const IngredientCategory(this.label);
}

/// วัตถุดิบในฐานข้อมูลของแอป
class Ingredient {
  final String id;
  final String nameTh;
  final String nameEn;
  final String emoji;
  final IngredientCategory category;

  /// ชื่ออื่นที่หมายถึงวัตถุดิบเดียวกัน (ใช้จับคู่แบบตรงทั้งคำ)
  final List<String> synonyms;

  /// เครื่องปรุงพื้นฐานที่ส่วนใหญ่มีติดครัว (ไม่นับเป็น "ของที่ขาด")
  final bool pantry;

  const Ingredient({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.emoji,
    required this.category,
    this.synonyms = const [],
    this.pantry = false,
  });

  Iterable<String> get allNames sync* {
    yield nameTh;
    yield* synonyms;
  }
}

const String unknownIngredientId = 'unknown';

/// วัตถุดิบทั้งหมดในฐานข้อมูล (รวมเครื่องปรุงพื้นฐาน)
List<Ingredient> get supportedIngredients => IngredientCatalog.all;

/// คืน Ingredient ที่รองรับ หรือ null ถ้าไม่อยู่ในฐานข้อมูล
Ingredient? findIngredient(String id) => IngredientCatalog.byId(id);

/// ที่มาของวัตถุดิบในรายการ (ใช้อธิบายผล ไม่ให้ปนกัน)
enum IngredientSource {
  ai('AI ตรวจพบ'),
  user('เพิ่มเอง');

  final String label;
  const IngredientSource(this.label);
}

/// วัตถุดิบที่ผู้ใช้มี — มาจาก AI ตรวจในภาพ หรือผู้ใช้เลือก/พิมพ์เอง
/// [known] = อยู่ในฐานข้อมูลของแอป (จับคู่กับสูตรได้แม่นยำ)
/// [source] = null สำหรับข้อมูลรุ่นเก่าที่ไม่ได้บันทึกที่มา
class DetectedIngredient {
  final String id;
  final String nameTh;
  final String? emoji;
  final bool known;
  final IngredientSource? source;

  const DetectedIngredient({
    required this.id,
    required this.nameTh,
    this.emoji,
    required this.known,
    this.source,
  });

  factory DetectedIngredient.fromCatalog(
    Ingredient i, {
    IngredientSource? source,
  }) => DetectedIngredient(
    id: i.id,
    nameTh: i.nameTh,
    emoji: i.emoji,
    known: true,
    source: source,
  );

  /// สร้างจากชื่อที่ผู้ใช้พิมพ์/AI ตอบ: ถ้าชื่อตรงกับฐานข้อมูลจะใช้ข้อมูลของแอป
  /// ชื่อที่ไม่อยู่ในฐานข้อมูลเก็บตามที่พิมพ์ (ไม่เดาจับคู่กับชนิดที่สะกดคล้าย)
  factory DetectedIngredient.fromName(String name, {IngredientSource? source}) {
    final known = IngredientCatalog.resolve(name);
    if (known != null) {
      return DetectedIngredient.fromCatalog(known, source: source);
    }
    final clean = name.trim();
    return DetectedIngredient(
      id: clean,
      nameTh: clean,
      known: false,
      source: source,
    );
  }

  DetectedIngredient withSource(IngredientSource? s) => DetectedIngredient(
    id: id,
    nameTh: nameTh,
    emoji: emoji,
    known: known,
    source: s,
  );

  /// เป็นเครื่องปรุงพื้นฐานในครัว (เช่น น้ำปลา น้ำมัน)
  bool get isPantry => known && (findIngredient(id)?.pantry ?? false);

  String get label => emoji == null ? nameTh : '$emoji $nameTh';

  @override
  bool operator ==(Object other) =>
      other is DetectedIngredient && other.id == id && other.nameTh == nameTh;

  @override
  int get hashCode => Object.hash(id, nameTh);
}

extension DetectedIngredientJson on DetectedIngredient {
  Map<String, dynamic> toJson() => {
    'id': id,
    'nameTh': nameTh,
    'emoji': emoji,
    'known': known,
    if (source != null) 'source': source!.name,
  };
}

/// อ่านจาก JSON — ข้อมูลเก่าที่ยังไม่รู้จัก แต่ตอนนี้มีในฐานข้อมูลแล้ว จะถูกยกระดับเป็น known
DetectedIngredient detectedIngredientFromJson(Map<String, dynamic> json) {
  final id = json['id'] as String;
  final name = json['nameTh'] as String;
  final rawSource = json['source'];
  IngredientSource? source;
  for (final s in IngredientSource.values) {
    if (s.name == rawSource) source = s;
  }
  final known = findIngredient(id) ?? IngredientCatalog.resolve(name);
  if (known != null) {
    return DetectedIngredient.fromCatalog(known, source: source);
  }
  return DetectedIngredient(
    id: id,
    nameTh: name,
    emoji: json['emoji'] as String?,
    known: false,
    source: source,
  );
}
