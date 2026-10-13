import 'package:flutter/foundation.dart';

/// ชนิดของคำขอไปยังบริการ AI
enum AiTraceKind {
  recognize('ตรวจวัตถุดิบจากภาพ'),
  suggest('แนะนำเมนู'),
  test('ทดสอบการเชื่อมต่อ');

  final String label;
  const AiTraceKind(this.label);
}

/// บันทึกการเรียก AI หนึ่งครั้ง สำหรับหน้าสรุป/โหมดสาธิต
/// เก็บเฉพาะข้อมูลที่ไม่ลับ: ไม่มี API key, header หรือ path ของไฟล์ในเครื่อง
@immutable
class AiTrace {
  final String requestId;
  final AiTraceKind kind;
  final DateTime startedAt;

  /// เวลาที่วัดจริงตั้งแต่ส่งคำขอจนได้ผล/ล้มเหลว
  final int durationMs;

  /// ปลายทางแบบตัดข้อมูลลับ (scheme + host + path ไม่มี query)
  final String endpoint;
  final String model;
  final String promptVersion;

  /// สรุป input เช่น "image/jpeg 182 KB" หรือ "วัตถุดิบ 3 รายการ"
  final String inputSummary;
  final int? httpStatus;
  final String? finishReason;

  /// ผลของ parser/validation เช่น ok, empty, invalid, truncated, error
  final String parserStatus;

  /// หมายเหตุจากการตรวจ เช่น "สูตรที่ 2 ถูกตัด: ไม่มีขั้นตอน"
  final List<String> notes;

  /// ข้อความตอบกลับของโมเดลที่ตัดความยาวและลบค่าลับแล้ว
  final String responseExcerpt;
  final String? errorType;

  const AiTrace({
    required this.requestId,
    required this.kind,
    required this.startedAt,
    required this.durationMs,
    required this.endpoint,
    required this.model,
    required this.promptVersion,
    required this.inputSummary,
    required this.parserStatus,
    this.httpStatus,
    this.finishReason,
    this.notes = const [],
    this.responseExcerpt = '',
    this.errorType,
  });

  static const maxExcerpt = 1500;

  AiTrace copyWith({
    String? parserStatus,
    List<String>? notes,
    String? errorType,
  }) => AiTrace(
    requestId: requestId,
    kind: kind,
    startedAt: startedAt,
    durationMs: durationMs,
    endpoint: endpoint,
    model: model,
    promptVersion: promptVersion,
    inputSummary: inputSummary,
    httpStatus: httpStatus,
    finishReason: finishReason,
    parserStatus: parserStatus ?? this.parserStatus,
    notes: notes ?? this.notes,
    responseExcerpt: responseExcerpt,
    errorType: errorType ?? this.errorType,
  );

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'kind': kind.name,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'durationMs': durationMs,
    'endpoint': endpoint,
    'model': model,
    'promptVersion': promptVersion,
    'inputSummary': inputSummary,
    'httpStatus': httpStatus,
    'finishReason': finishReason,
    'parserStatus': parserStatus,
    'notes': notes,
    'responseExcerpt': responseExcerpt,
    'errorType': errorType,
  };

  static AiTrace? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return AiTrace(
        requestId: raw['requestId'] as String,
        kind: AiTraceKind.values.firstWhere(
          (k) => k.name == raw['kind'],
          orElse: () => AiTraceKind.suggest,
        ),
        startedAt: DateTime.fromMillisecondsSinceEpoch(raw['startedAt'] as int),
        durationMs: raw['durationMs'] as int? ?? 0,
        endpoint: raw['endpoint'] as String? ?? '',
        model: raw['model'] as String? ?? '',
        promptVersion: raw['promptVersion'] as String? ?? '',
        inputSummary: raw['inputSummary'] as String? ?? '',
        httpStatus: raw['httpStatus'] as int?,
        finishReason: raw['finishReason'] as String?,
        parserStatus: raw['parserStatus'] as String? ?? '',
        notes: [for (final n in (raw['notes'] as List? ?? const [])) '$n'],
        responseExcerpt: raw['responseExcerpt'] as String? ?? '',
        errorType: raw['errorType'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// ตัดข้อมูลลับออกจากข้อความก่อนเก็บ/แสดง
String sanitizeForTrace(
  String text, {
  String? secret,
  int max = AiTrace.maxExcerpt,
}) {
  var s = text;
  if (secret != null && secret.length >= 4) s = s.replaceAll(secret, '***');
  // รูปแบบที่ดูเหมือน key/bearer token
  s = s.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._\-]+'), 'Bearer ***');
  s = s.replaceAll(RegExp(r'\b(sk|AIza|key)[-_A-Za-z0-9]{12,}'), '***');
  // ข้อมูลภาพ base64 ยาว ๆ ไม่จำเป็นต่อการอธิบาย
  s = s.replaceAll(
    RegExp(r'data:image/[a-z+]+;base64,[A-Za-z0-9+/=]+'),
    'data:image/...;base64,…',
  );
  return s.length > max ? '${s.substring(0, max)}…' : s;
}

/// URL ที่ไม่มี query/fragment/userinfo
String sanitizeEndpoint(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return '(ไม่ถูกต้อง)';
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port${uri.path}';
}
