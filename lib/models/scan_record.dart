import 'ai_trace.dart';
import 'cooking_conditions.dart';
import 'ingredient.dart';
import 'ingredient_recognition_result.dart';
import 'recipe.dart';

/// สถานะของการสแกน
enum ScanStatus {
  /// ผล AI ที่ยังไม่ได้ตรวจ/ยืนยัน (เก็บแยกจากประวัติ)
  draft('ยังไม่ยืนยัน'),

  /// ผู้ใช้ยืนยันรายการวัตถุดิบแล้ว
  confirmed('ยืนยันแล้ว'),

  /// บันทึกจากเวอร์ชันก่อนที่ไม่มีขั้นยืนยัน — ต้องตรวจก่อนใช้หาเมนู
  legacy('ข้อมูลเวอร์ชันเก่า');

  final String label;
  const ScanStatus(this.label);
}

/// การแก้ชื่อวัตถุดิบหนึ่งรายการ (ชื่อเดิมจาก AI → ชื่อที่ผู้ใช้แก้)
class IngredientRename {
  final String from;
  final String to;

  const IngredientRename(this.from, this.to);

  Map<String, dynamic> toJson() => {'from': from, 'to': to};

  static IngredientRename? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final from = raw['from'], to = raw['to'];
    if (from is! String || to is! String) return null;
    return IngredientRename(from, to);
  }

  @override
  bool operator ==(Object other) =>
      other is IngredientRename && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// ความแตกต่างระหว่างผล AI กับรายการที่ผู้ใช้ยืนยัน
class ChangeSet {
  final List<DetectedIngredient> added;
  final List<DetectedIngredient> removed;
  final List<IngredientRename> renamed;

  const ChangeSet({
    this.added = const [],
    this.removed = const [],
    this.renamed = const [],
  });

  bool get isEmpty => added.isEmpty && removed.isEmpty && renamed.isEmpty;

  /// เทียบด้วยชื่อไทย: ชื่อที่ถูกแก้ไม่นับเป็นทั้ง "ลบ" และ "เพิ่ม"
  factory ChangeSet.compute(
    List<DetectedIngredient> detected,
    List<DetectedIngredient> confirmed,
    List<IngredientRename> renames,
  ) {
    final renamedFrom = {for (final r in renames) r.from};
    final renamedTo = {for (final r in renames) r.to};
    final detectedNames = {for (final d in detected) d.nameTh};
    final confirmedNames = {for (final c in confirmed) c.nameTh};
    return ChangeSet(
      added: [
        for (final c in confirmed)
          if (!detectedNames.contains(c.nameTh) &&
              !renamedTo.contains(c.nameTh))
            c,
      ],
      removed: [
        for (final d in detected)
          if (!confirmedNames.contains(d.nameTh) &&
              !renamedFrom.contains(d.nameTh))
            d,
      ],
      renamed: [
        for (final r in renames)
          if (confirmedNames.contains(r.to) && detectedNames.contains(r.from))
            r,
      ],
    );
  }
}

/// สูตรที่ AI แนะนำ พร้อมคีย์ของ input ที่ใช้ขอ (ใช้ตัดสินว่ายังตรงกับรายการปัจจุบันไหม)
class AiRecipeCache {
  final List<Recipe> recipes;

  /// null = ข้อมูลรุ่นเก่าที่ไม่ได้บันทึกว่าขอจาก input ใด
  final String? inputKey;
  final DateTime? createdAt;
  final List<String> rejectedNotes;

  const AiRecipeCache({
    required this.recipes,
    this.inputKey,
    this.createdAt,
    this.rejectedNotes = const [],
  });

  Map<String, dynamic> toJson() => {
    'recipes': [for (final r in recipes) r.toJson()],
    'inputKey': inputKey,
    'createdAt': createdAt?.millisecondsSinceEpoch,
    'rejectedNotes': rejectedNotes,
  };

  static AiRecipeCache? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final list = raw['recipes'];
    if (list is! List) return null;
    final created = raw['createdAt'];
    return AiRecipeCache(
      recipes: [
        for (final r in list)
          recipeFromJson(Map<String, dynamic>.from(r as Map)),
      ],
      inputKey: raw['inputKey'] as String?,
      createdAt: created is int
          ? DateTime.fromMillisecondsSinceEpoch(created)
          : null,
      rejectedNotes: [
        for (final n in (raw['rejectedNotes'] as List? ?? const [])) '$n',
      ],
    );
  }
}

/// การสแกน (หรือการเลือกวัตถุดิบเอง) หนึ่งครั้ง
class ScanRecord {
  static const maxTraces = 6;

  final String id;
  final DateTime createdAt;

  /// ชื่อไฟล์รูปในโฟลเดอร์ scans ของแอป (null = เลือกวัตถุดิบเอง/เก็บรูปไม่สำเร็จ)
  /// เก็บเฉพาะชื่อไฟล์ เพราะ path ของโฟลเดอร์แอปอาจเปลี่ยนเมื่ออัปเดต/กู้คืนเครื่อง
  final String? imageFile;

  /// true = ผู้ใช้เลือกวัตถุดิบเองโดยไม่ได้ถ่ายรูป
  final bool manual;

  final ScanStatus status;

  /// ผลที่ AI ตรวจพบ (หลัง normalize) — ไม่เปลี่ยนเมื่อผู้ใช้แก้ ใช้เทียบก่อน–หลัง
  final List<DetectedIngredient> detected;

  /// จำนวนรายการที่ AI ตอบมาก่อนตัดตามขีดจำกัด (null = ไม่ทราบ/เลือกเอง)
  final int? aiReportedCount;

  /// รายการปัจจุบัน: draft = รายการที่กำลังตรวจ, confirmed = รายการที่ยืนยันแล้ว
  final List<DetectedIngredient> ingredients;
  final List<IngredientRename> renames;

  /// ของพื้นฐานในครัวที่ผู้ใช้ยืนยันว่ามี (id ใน catalog) ณ ตอนยืนยัน
  final Set<String> kitchen;
  final DateTime? confirmedAt;
  final CookingConditions conditions;

  /// เมนูที่ AI แนะนำ (เก็บไว้ จะได้ไม่ต้องเรียก AI ซ้ำ)
  final AiRecipeCache? ai;

  /// การเรียก AI ที่เกี่ยวกับการสแกนนี้ (ล่าสุดอยู่ท้าย) สำหรับหน้าสรุป
  final List<AiTrace> traces;

  const ScanRecord({
    required this.id,
    required this.createdAt,
    required this.ingredients,
    this.imageFile,
    this.manual = false,
    this.status = ScanStatus.confirmed,
    this.detected = const [],
    this.aiReportedCount,
    this.renames = const [],
    this.kitchen = const {},
    this.confirmedAt,
    this.conditions = CookingConditions.standard,
    this.ai,
    this.traces = const [],
  });

  bool get isConfirmed => status == ScanStatus.confirmed;

  List<Recipe> get aiRecipes => ai?.recipes ?? const [];

  IngredientRecognitionResult get result =>
      IngredientRecognitionResult(ingredients);

  ChangeSet get changes => ChangeSet.compute(detected, ingredients, renames);

  String get title => ingredients.isEmpty
      ? (manual ? 'เลือกวัตถุดิบเอง' : 'ไม่พบวัตถุดิบ')
      : ingredients.map((i) => i.nameTh).join(' · ');

  ScanRecord copyWith({
    ScanStatus? status,
    List<DetectedIngredient>? ingredients,
    List<IngredientRename>? renames,
    Set<String>? kitchen,
    DateTime? confirmedAt,
    CookingConditions? conditions,
    Object? ai = _keep,
    List<AiTrace>? traces,
  }) => ScanRecord(
    id: id,
    createdAt: createdAt,
    imageFile: imageFile,
    manual: manual,
    status: status ?? this.status,
    detected: detected,
    aiReportedCount: aiReportedCount,
    ingredients: ingredients ?? this.ingredients,
    renames: renames ?? this.renames,
    kitchen: kitchen ?? this.kitchen,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    conditions: conditions ?? this.conditions,
    ai: ai == _keep ? this.ai : ai as AiRecipeCache?,
    traces: traces ?? this.traces,
  );

  /// เพิ่ม trace (เก็บเฉพาะล่าสุด [maxTraces] รายการ)
  ScanRecord withTrace(AiTrace trace) {
    final list = [...traces, trace];
    return copyWith(
      traces: list.length > maxTraces
          ? list.sublist(list.length - maxTraces)
          : list,
    );
  }

  Map<String, dynamic> toJson() => {
    'v': 2,
    'id': id,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'imageFile': imageFile,
    'manual': manual,
    'status': status.name,
    'detected': [for (final i in detected) i.toJson()],
    'aiReportedCount': aiReportedCount,
    'ingredients': [for (final i in ingredients) i.toJson()],
    'renames': [for (final r in renames) r.toJson()],
    'kitchen': kitchen.toList()..sort(),
    'confirmedAt': confirmedAt?.millisecondsSinceEpoch,
    'conditions': conditions.toJson(),
    'ai': ai?.toJson(),
    'traces': [for (final t in traces) t.toJson()],
  };

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    List<DetectedIngredient> list(Object? raw) => [
      for (final i in (raw as List? ?? const []))
        detectedIngredientFromJson(Map<String, dynamic>.from(i as Map)),
    ];

    final rawStatus = json['status'];
    final manual = json['manual'] as bool? ?? false;
    final ScanStatus status;
    if (rawStatus is String) {
      status = ScanStatus.values.firstWhere(
        (s) => s.name == rawStatus,
        orElse: () => ScanStatus.legacy,
      );
    } else {
      // ข้อมูลก่อน v1.2: การเลือกเองผ่านปุ่มยืนยันของตัวเลือกอยู่แล้ว (นับเป็นยืนยัน)
      // ส่วนผลจากรูปไม่มีหลักฐานว่าผู้ใช้ตรวจ จึงเป็น legacy
      status = manual ? ScanStatus.confirmed : ScanStatus.legacy;
    }

    final ingredients = list(json['ingredients']);
    // ผลรุ่นเก่า: รายการที่บันทึกไว้คือผล AI (เท่าที่รู้) → ใช้เป็น detected ด้วย
    final detected = json.containsKey('detected')
        ? list(json['detected'])
        : (manual ? <DetectedIngredient>[] : ingredients);

    AiRecipeCache? ai = AiRecipeCache.fromJson(json['ai']);
    final legacyAi = json['aiRecipes'];
    if (ai == null && legacyAi is List && legacyAi.isNotEmpty) {
      ai = AiRecipeCache(
        recipes: [
          for (final r in legacyAi)
            recipeFromJson(Map<String, dynamic>.from(r as Map)),
        ],
      );
    }
    final confirmedAt = json['confirmedAt'];
    return ScanRecord(
      id: json['id'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      // ข้อมูลรุ่นแรกเก็บ path เต็มใน imagePath → ใช้แค่ชื่อไฟล์
      imageFile:
          json['imageFile'] as String? ??
          fileNameOf(json['imagePath'] as String?),
      manual: manual,
      status: status,
      detected: detected,
      aiReportedCount: json['aiReportedCount'] as int?,
      ingredients: ingredients,
      renames: [
        for (final r in (json['renames'] as List? ?? const []))
          ?IngredientRename.fromJson(r),
      ],
      kitchen: {for (final k in (json['kitchen'] as List? ?? const [])) '$k'},
      confirmedAt: confirmedAt is int
          ? DateTime.fromMillisecondsSinceEpoch(confirmedAt)
          : null,
      conditions: CookingConditions.fromJson(json['conditions']),
      ai: ai,
      traces: [
        for (final t in (json['traces'] as List? ?? const []))
          ?AiTrace.fromJson(t),
      ],
    );
  }
}

const _keep = Object();

/// ตัดเอาเฉพาะชื่อไฟล์จาก path (รองรับทั้ง / และ \)
String? fileNameOf(String? path) {
  if (path == null || path.isEmpty) return null;
  final parts = path.split(RegExp(r'[\\/]'));
  final name = parts.last;
  return name.isEmpty ? null : name;
}
