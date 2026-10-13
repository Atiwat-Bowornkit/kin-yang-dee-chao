import 'package:flutter/foundation.dart';

/// อุปกรณ์ทำอาหารที่ใช้กรองสูตร (เฉพาะอุปกรณ์หลัก ไม่รวมมีด/ครก/ชาม)
enum Equipment {
  pan('กระทะ'),
  pot('หม้อ'),
  steamer('ซึ้ง/หม้อนึ่ง'),
  microwave('ไมโครเวฟ'),
  oven('เตาอบ'),
  blender('เครื่องปั่น');

  final String label;
  const Equipment(this.label);

  static Equipment? parse(Object? raw) {
    final s = raw?.toString().toLowerCase().trim() ?? '';
    for (final e in values) {
      if (e.name.toLowerCase() == s || e.label == s) return e;
    }
    return switch (s) {
      'wok' || 'frying_pan' || 'skillet' => pan,
      'saucepan' || 'pot_or_saucepan' => pot,
      'steam' || 'steamer_pot' => steamer,
      _ => null,
    };
  }
}

/// ความเผ็ดที่รับได้
enum SpicePreference {
  any('เผ็ดได้'),
  mild('ไม่เผ็ด');

  final String label;
  const SpicePreference(this.label);
}

/// เงื่อนไขที่ผู้ใช้เลือกก่อนขอเมนู ใช้ทั้งกรองสูตรในแอปและเป็น input ของ AI
@immutable
class CookingConditions {
  /// เวลารวมสูงสุด (นาที) — null = ไม่จำกัด
  final int? maxMinutes;
  final int servings;

  /// อุปกรณ์ที่มี — null = ไม่ระบุ (ไม่กรอง), เซตว่าง = ไม่ใช้อุปกรณ์ให้ความร้อนเลย
  final Set<Equipment>? equipment;
  final SpicePreference spice;

  static const timeOptions = <int?>[null, 15, 30];
  static const minServings = 1;
  static const maxServings = 12;

  const CookingConditions({
    this.maxMinutes,
    this.servings = 2,
    this.equipment,
    this.spice = SpicePreference.any,
  });

  static const standard = CookingConditions();

  bool get isDefault =>
      maxMinutes == null && equipment == null && spice == SpicePreference.any;

  CookingConditions copyWith({
    Object? maxMinutes = _keep,
    int? servings,
    Object? equipment = _keep,
    SpicePreference? spice,
  }) => CookingConditions(
    maxMinutes: maxMinutes == _keep ? this.maxMinutes : maxMinutes as int?,
    servings: (servings ?? this.servings).clamp(minServings, maxServings),
    equipment: equipment == _keep
        ? this.equipment
        : equipment as Set<Equipment>?,
    spice: spice ?? this.spice,
  );

  String get timeLabel =>
      maxMinutes == null ? 'ไม่จำกัดเวลา' : 'ไม่เกิน $maxMinutes นาที';

  String get equipmentLabel {
    final e = equipment;
    if (e == null) return 'อุปกรณ์: ไม่ระบุ';
    if (e.isEmpty) return 'ไม่ใช้เตา/อุปกรณ์ให้ความร้อน';
    return [
      for (final x in Equipment.values)
        if (e.contains(x)) x.label,
    ].join(' · ');
  }

  /// สรุปสั้น ๆ สำหรับแสดงผลและบันทึก
  List<String> get summary => [
    timeLabel,
    '$servings ที่',
    equipmentLabel,
    spice.label,
  ];

  /// คีย์คงที่ (ใช้ผูก cache ของสูตร AI กับเงื่อนไข)
  String get cacheKey {
    final e = equipment == null
        ? '*'
        : ([for (final x in equipment!) x.name]..sort()).join(',');
    return 't=${maxMinutes ?? '*'};s=$servings;e=$e;p=${spice.name}';
  }

  Map<String, dynamic> toJson() => {
    'maxMinutes': maxMinutes,
    'servings': servings,
    'equipment': equipment == null
        ? null
        : [for (final x in equipment!) x.name],
    'spice': spice.name,
  };

  factory CookingConditions.fromJson(Object? raw) {
    if (raw is! Map) return standard;
    final eq = raw['equipment'];
    final minutes = raw['maxMinutes'];
    final servings = raw['servings'];
    return CookingConditions(
      maxMinutes: minutes is num && minutes > 0 ? minutes.round() : null,
      servings: servings is num
          ? servings.round().clamp(minServings, maxServings)
          : 2,
      equipment: eq is List ? {for (final x in eq) ?Equipment.parse(x)} : null,
      spice: raw['spice'] == SpicePreference.mild.name
          ? SpicePreference.mild
          : SpicePreference.any,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CookingConditions && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;
}

const _keep = Object();
