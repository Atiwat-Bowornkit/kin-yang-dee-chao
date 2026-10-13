import '../data/catalog/ingredients_catalog.dart';
import 'ingredient.dart';

/// ข้อมูลจาก AI ผิดรูปแบบ (แยกจาก "ไม่พบวัตถุดิบ" ที่เป็นผลปกติ)
class InvalidAiOutput implements Exception {
  final String reason;
  const InvalidAiOutput(this.reason);

  @override
  String toString() => 'InvalidAiOutput($reason)';
}

/// ผลการจำแนกวัตถุดิบ (หลายชนิดต่อภาพ และไม่จำกัดเฉพาะชนิดที่อยู่ในฐานข้อมูล)
class IngredientRecognitionResult {
  /// ขีดจำกัดเดียวกันทั้ง prompt, parser และตัวเลือกวัตถุดิบ
  static const maxIngredients = 12;
  static const maxNameLength = 40;

  final List<DetectedIngredient> ingredients;

  /// จำนวนรายการที่ AI ตอบมา (ก่อนตัดซ้ำ/ตัดตามขีดจำกัด)
  final int reportedCount;

  /// จำนวนที่ไม่ได้แสดงเพราะเกิน [maxIngredients]
  final int overLimit;

  /// จำนวนที่ถูกตัดทิ้งเพราะรูปแบบผิด/ชื่อว่าง/ซ้ำ
  final int skipped;

  const IngredientRecognitionResult(
    this.ingredients, {
    int? reportedCount,
    this.overLimit = 0,
    this.skipped = 0,
  }) : reportedCount = reportedCount ?? ingredients.length;

  bool get supported => ingredients.isNotEmpty;

  /// ID ของชนิดที่อยู่ในฐานข้อมูล
  List<String> get knownIds => [
    for (final i in ingredients)
      if (i.known) i.id,
  ];

  List<String> get names => [for (final i in ingredients) i.nameTh];

  /// สร้างจาก JSON ของ AI โดย validate ทุกค่า:
  /// - ต้องมี "ingredients" เป็น list (ว่างได้ = ไม่พบวัตถุดิบ)
  /// - แต่ละรายการเป็น string (id) หรือ object {id, name_th} ที่เป็นข้อความ
  /// - ชนิดที่อยู่ในฐานข้อมูล (จับคู่จาก id หรือชื่อไทยแบบตรงทั้งคำ) ใช้ชื่อ/emoji จากแอป
  /// - ชนิดอื่นใช้ชื่อไทยจาก AI (ตัดความยาว ลบอักขระควบคุม) ไม่เดาจับคู่กับชนิดที่สะกดคล้าย
  /// - ไม่ซ้ำ และจำกัดจำนวน โดยนับรายการที่ตัดไว้ให้ UI แจ้งผู้ใช้
  /// โยน [InvalidAiOutput] เมื่อโครงสร้างผิด หรือทุกรายการผิดรูปแบบ
  factory IngredientRecognitionResult.fromAiJson(Map<String, dynamic> json) {
    final list = json['ingredients'];
    if (list is! List) {
      throw const InvalidAiOutput('ไม่มีฟิลด์ ingredients ที่เป็นรายการ');
    }

    final result = <DetectedIngredient>[];
    final seen = <String>{};
    var skipped = 0;
    var overLimit = 0;
    var malformed = 0;

    for (final item in list) {
      String? id;
      String? nameTh;
      if (item is Map) {
        final rawId = item['id'];
        final rawName = item['name_th'];
        if ((rawId != null && rawId is! String) ||
            (rawName != null && rawName is! String)) {
          malformed++;
          continue;
        }
        id = rawId as String?;
        nameTh = rawName as String?;
      } else if (item is String) {
        id = item;
      } else {
        malformed++;
        continue;
      }

      final normalizedId = (id ?? '').trim().toLowerCase();
      final known =
          findIngredient(normalizedId) ??
          IngredientCatalog.resolve(nameTh) ??
          IngredientCatalog.resolve(id);
      final DetectedIngredient detected;
      if (known != null) {
        detected = DetectedIngredient.fromCatalog(
          known,
          source: IngredientSource.ai,
        );
      } else {
        final name = cleanName(nameTh ?? id);
        if (name.isEmpty || name.toLowerCase() == unknownIngredientId) {
          skipped++;
          continue;
        }
        detected = DetectedIngredient(
          id: normalizedId.isEmpty ? name : normalizedId,
          nameTh: name,
          known: false,
          source: IngredientSource.ai,
        );
      }

      if (!seen.add(detected.nameTh)) {
        skipped++;
        continue;
      }
      if (result.length >= maxIngredients) {
        overLimit++;
        continue;
      }
      result.add(detected);
    }

    if (list.isNotEmpty && result.isEmpty && malformed > 0) {
      throw const InvalidAiOutput('รายการวัตถุดิบผิดรูปแบบทั้งหมด');
    }
    return IngredientRecognitionResult(
      result,
      reportedCount: list.length,
      overLimit: overLimit,
      skipped: skipped + malformed,
    );
  }

  static String cleanName(String? raw) {
    final s = (raw ?? '')
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s.length > maxNameLength ? s.substring(0, maxNameLength) : s;
  }
}
