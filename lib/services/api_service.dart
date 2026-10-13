import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:uuid/uuid.dart';

import '../data/catalog/ingredients_catalog.dart';
import '../models/ai_trace.dart';
import '../models/cooking_conditions.dart';
import '../models/ingredient.dart';
import '../models/ingredient_recognition_result.dart';
import '../models/recipe.dart';
import '../state/ai_config_controller.dart';

enum RecognitionErrorType {
  missingApiKey,
  invalidConfig,
  unauthorized,
  rateLimited,
  badRequest,
  network,
  timeout,
  service,
  invalidResponse,
  truncated,
  imageTooLarge,
  cancelled,
}

/// ข้อผิดพลาดจากการเรียก AI (แยกจากผล "ไม่พบวัตถุดิบ" ที่เป็นผลปกติ)
class RecognitionException implements Exception {
  final RecognitionErrorType type;

  /// บันทึกการเรียกครั้งนั้น (ถ้าส่งคำขอไปแล้ว) สำหรับหน้าสรุป/โหมดสาธิต
  final AiTrace? trace;

  const RecognitionException(this.type, {this.trace});

  RecognitionException withTrace(AiTrace? t) =>
      RecognitionException(type, trace: t ?? trace);

  String get userMessage => switch (type) {
    RecognitionErrorType.missingApiKey =>
      'ยังไม่ได้ตั้งค่าการเชื่อมต่อ AI\nไปที่ ตั้งค่า › การเชื่อมต่อ AI เพื่อใส่ API key',
    RecognitionErrorType.invalidConfig =>
      'การตั้งค่า AI ไม่ถูกต้อง (Base URL หรือโมเดล)\nตรวจสอบได้ที่ ตั้งค่า › การเชื่อมต่อ AI',
    RecognitionErrorType.unauthorized =>
      'API key ไม่ถูกต้องหรือหมดอายุ\nกรุณาตรวจสอบในหน้า ตั้งค่า › การเชื่อมต่อ AI',
    RecognitionErrorType.rateLimited =>
      'เรียกใช้ AI ถี่เกินกำหนดหรือโควตาหมด\nรอสักครู่แล้วลองใหม่',
    RecognitionErrorType.badRequest =>
      'บริการ AI ปฏิเสธคำขอ (อาจเป็นชื่อโมเดลหรือรูปแบบที่ไม่รองรับ)\nตรวจสอบการตั้งค่าโมเดล',
    RecognitionErrorType.network =>
      'ไม่สามารถเชื่อมต่อบริการ AI ได้\nกรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
    RecognitionErrorType.timeout => 'บริการ AI ตอบช้าเกินไป\nกรุณาลองอีกครั้ง',
    RecognitionErrorType.service =>
      'บริการ AI ขัดข้องในขณะนี้\nกรุณาลองใหม่ภายหลัง',
    RecognitionErrorType.invalidResponse =>
      'AI ตอบกลับในรูปแบบที่อ่านไม่ได้\nกรุณาลองอีกครั้ง',
    RecognitionErrorType.truncated =>
      'คำตอบจาก AI ถูกตัดก่อนจบ จึงไม่ได้นำมาแสดง\nกรุณาลองอีกครั้ง',
    RecognitionErrorType.imageTooLarge =>
      'รูปมีขนาดใหญ่เกินไป\nกรุณาเลือกรูปที่เล็กลงหรือถ่ายใหม่',
    RecognitionErrorType.cancelled => 'ยกเลิกแล้ว',
  };

  @override
  String toString() => 'RecognitionException($type)';
}

/// ผลตรวจวัตถุดิบจากภาพ พร้อมบันทึกการเรียก
class RecognitionOutcome {
  final IngredientRecognitionResult result;
  final AiTrace trace;
  const RecognitionOutcome(this.result, this.trace);
}

/// สูตรที่ผ่านการตรวจ พร้อมเหตุผลของสูตรที่ถูกตัดทิ้ง
class SuggestionOutcome {
  final List<Recipe> recipes;
  final List<String> rejected;
  final AiTrace trace;
  const SuggestionOutcome(this.recipes, this.rejected, this.trace);
}

/// ผลแปลงสูตร AI หนึ่งรายการ: ได้สูตร หรือเหตุผลที่ไม่ผ่าน
class AiRecipeParse {
  final Recipe? recipe;
  final String? problem;
  const AiRecipeParse.ok(Recipe this.recipe) : problem = null;
  const AiRecipeParse.rejected(String this.problem) : recipe = null;
}

class _Reply {
  final String text;
  final String? finishReason;
  final int? status;
  const _Reply(this.text, this.finishReason, this.status);
}

/// ตัวจับเวลา + ข้อมูลประกอบ trace ของคำขอหนึ่งครั้ง
class _TraceRun {
  _TraceRun(this.kind, this.config, this.promptVersion, this.inputSummary)
    : requestId = const Uuid().v4().substring(0, 8),
      startedAt = DateTime.now(),
      _watch = Stopwatch()..start();

  final AiTraceKind kind;
  final AiConfig config;
  final String promptVersion;
  final String inputSummary;
  final String requestId;
  final DateTime startedAt;
  final Stopwatch _watch;
  int? status;
  String? finishReason;
  String excerpt = '';

  AiTrace finish(
    String parserStatus, {
    List<String> notes = const [],
    RecognitionErrorType? error,
  }) {
    _watch.stop();
    return AiTrace(
      requestId: requestId,
      kind: kind,
      startedAt: startedAt,
      durationMs: _watch.elapsedMilliseconds,
      endpoint: sanitizeEndpoint(ApiService.chatUrl(config.baseUrl)),
      model: config.model,
      promptVersion: promptVersion,
      inputSummary: inputSummary,
      httpStatus: status,
      finishReason: finishReason,
      parserStatus: parserStatus,
      notes: notes,
      responseExcerpt: excerpt,
      errorType: error?.name,
    );
  }
}

/// เรียกบริการ AI แบบ OpenAI-compatible (chat/completions)
/// แอปใช้โมเดลของผู้ให้บริการผ่าน API เท่านั้น ไม่ได้ฝึก/ปรับแต่งโมเดลเอง
class ApiService {
  ApiService(this._config, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 90),
              sendTimeout: const Duration(seconds: 60),
            ),
          );

  final AiConfig Function() _config;
  final Dio _dio;

  static const _uuid = Uuid();

  /// เปลี่ยนเมื่อ prompt/รูปแบบผลลัพธ์เปลี่ยน (cache ของสูตร AI ผูกกับค่านี้)
  static const recognitionPromptVersion = 'recognize-v2';
  static const recipePromptVersion = 'recipes-v2';

  /// ขนาดรูปสูงสุดที่ส่ง (picker ย่อเหลือ ~1280px อยู่แล้ว ปกติไม่ถึง 1 MB)
  static const maxImageBytes = 6 * 1024 * 1024;
  static const recipeCount = 3;

  static const _recognitionSystemPrompt = '''
You are an ingredient image recognition assistant.

Your task is to identify every distinct food ingredient clearly visible in the image
(vegetables, fruits, meat, seafood, eggs, dairy, grains, noodles, herbs, etc.).

Ignore non-food objects, packaging brands, people and background.
Ignore basic seasonings such as salt, sugar, water, cooking oil unless clearly visible.
Only list what you can clearly see. Do not guess.
Do not provide recipes or explanations.
Return only the requested JSON structure.''';

  static String _recognitionUserPrompt() {
    final known = [
      for (final i in IngredientCatalog.selectable) '${i.id} (${i.nameTh})',
    ].join(', ');
    return '''
Analyze this image and list ALL visible food ingredients.

Return STRICT valid JSON:

{
  "ingredients": [
    {"id": "egg", "name_th": "ไข่ไก่"},
    {"id": "onion", "name_th": "หอมใหญ่"}
  ]
}

Rules:
1. If the ingredient is one of these known ids, you MUST use exactly that id:
   $known
2. Otherwise "id" is a short lowercase English singular noun (snake_case).
3. "name_th" is the common Thai name of the ingredient.
4. List each ingredient at most once, at most ${IngredientRecognitionResult.maxIngredients} items, most prominent first.
5. If no food ingredient is clearly visible, return {"ingredients": []}
6. No markdown, no code fences, no text outside JSON.''';
  }

  static const _recipeSystemPrompt = '''
You are a helpful Thai home-cooking assistant.
Suggest simple, realistic dishes that a student can cook at home.
Respect every constraint given by the user. Reply only with the requested JSON.''';

  static String recipeUserPrompt(
    List<DetectedIngredient> owned,
    Set<String> kitchen,
    CookingConditions c,
  ) {
    final items = owned.map((i) => i.nameTh).join(', ');
    final staples = [
      for (final id in kitchen) ?IngredientCatalog.byId(id)?.nameTh,
    ].join(', ');
    final eq = c.equipment;
    final equipment = eq == null
        ? 'ไม่ระบุ (ใช้อุปกรณ์ครัวทั่วไปได้)'
        : eq.isEmpty
        ? 'ไม่มีเตาหรืออุปกรณ์ให้ความร้อน (ต้องเป็นเมนูไม่ใช้ความร้อน)'
        : 'มีเฉพาะ ${[for (final e in eq) e.label].join(', ')}';
    return 'วัตถุดิบที่ผู้ใช้ยืนยันว่ามี: $items\n'
        'ของพื้นฐานในครัวที่มี: ${staples.isEmpty ? 'ไม่ได้ระบุ' : staples}\n'
        'เงื่อนไข:\n'
        '- เวลารวม: ${c.maxMinutes == null ? 'ไม่จำกัด' : 'ไม่เกิน ${c.maxMinutes} นาที'}\n'
        '- จำนวนที่: ${c.servings} ที่ (ปริมาณส่วนผสมสำหรับ ${c.servings} ที่)\n'
        '- อุปกรณ์: $equipment\n'
        '- ความเผ็ด: ${c.spice == SpicePreference.mild ? 'ต้องไม่เผ็ด' : 'เผ็ดได้'}\n'
        'แนะนำเมนูอาหาร $recipeCount เมนูที่ทำได้ง่ายโดยใช้วัตถุดิบที่มีเป็นหลัก '
        '(ไม่จำเป็นต้องใช้ครบทุกอย่าง) ตอบเป็นภาษาไทย\n'
        'Return STRICT valid JSON only, no markdown:\n'
        '{"recipes":[{"name_th":"ชื่อเมนู","description":"คำอธิบายสั้น 1 ประโยค",'
        '"category":"main|soup|salad|noodle|breakfast|dessert",'
        '"difficulty":"easy|medium|hard","prep_minutes":10,"cook_minutes":15,'
        '"servings":${c.servings},"spicy":false,'
        '"equipment":["pan|pot|steamer|microwave|oven|blender"],'
        '"ingredients":[{"name":"ชื่อส่วนผสม","amount":2,"unit":"ฟอง","optional":false}],'
        '"steps":["ขั้นตอนสั้น ๆ"]}]}\n'
        'Rules: exactly $recipeCount recipes; 3-12 ingredients each including the ones the user has; '
        'amount is a number or null; 3-8 steps each, one short sentence per step; '
        '"equipment" lists only the heating/blending equipment the steps really need ([] if none); '
        '"spicy" is true if the dish is spicy.';
  }

  /// คีย์ของ input ที่ใช้ขอสูตร AI — ถ้าค่าใดเปลี่ยน ผลที่บันทึกไว้ถือว่าเป็น "ผลเก่า"
  static String suggestionInputKey({
    required List<DetectedIngredient> owned,
    required Set<String> kitchen,
    required CookingConditions conditions,
    required AiConfig config,
  }) {
    final names = [for (final i in owned) IngredientCatalog.normalize(i.nameTh)]
      ..sort();
    final k = kitchen.toList()..sort();
    return [
      recipePromptVersion,
      config.model,
      sanitizeEndpoint(chatUrl(config.baseUrl)),
      names.join(','),
      k.join(','),
      conditions.cacheKey,
    ].join('|');
  }

  static String chatUrl(String baseUrl) {
    final base = baseUrl.trim().endsWith('/')
        ? baseUrl.trim().substring(0, baseUrl.trim().length - 1)
        : baseUrl.trim();
    return '$base/chat/completions';
  }

  /// ตรวจ Base URL: ต้องเป็น https (ยกเว้นเครื่องที่พัฒนาในเครื่อง) เพื่อไม่ส่ง key แบบไม่เข้ารหัส
  static String? validateBaseUrl(String url) {
    final s = url.trim();
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty || uri.hasQuery || uri.hasFragment) {
      return 'รูปแบบ URL ไม่ถูกต้อง';
    }
    if (uri.userInfo.isNotEmpty) return 'URL ต้องไม่มีชื่อผู้ใช้/รหัสผ่าน';
    const local = {'localhost', '127.0.0.1', '10.0.2.2'};
    if (uri.isScheme('https')) return null;
    if (uri.isScheme('http') && local.contains(uri.host)) return null;
    return 'ต้องขึ้นต้นด้วย https:// เพื่อไม่ให้ API key ถูกส่งแบบไม่เข้ารหัส';
  }

  static String _mimeOf(XFile image) {
    final mime = image.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;
    final name = image.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  Future<RecognitionOutcome> recognizeIngredient(
    XFile image, {
    CancelToken? cancelToken,
  }) async {
    final config = _requireConfig();
    final size = await image.length();
    if (size > maxImageBytes) {
      throw const RecognitionException(RecognitionErrorType.imageTooLarge);
    }
    final mime = _mimeOf(image);
    final run = _TraceRun(
      AiTraceKind.recognize,
      config,
      recognitionPromptVersion,
      '$mime ${(size / 1024).round()} KB',
    );
    try {
      final bytes = await image.readAsBytes();
      final reply = await _post(
        config,
        {
          'model': config.model,
          'messages': [
            {'role': 'system', 'content': _recognitionSystemPrompt},
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': _recognitionUserPrompt()},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mime;base64,${base64Encode(bytes)}',
                  },
                },
              ],
            },
          ],
          // โมเดลแบบ thinking ใช้ token ส่วนหนึ่งกับการคิด จึงเผื่อไว้มาก
          'max_tokens': 4000,
        },
        cancelToken,
        run,
      );

      final json = decodeJsonObject(reply.text);
      final IngredientRecognitionResult result;
      try {
        result = IngredientRecognitionResult.fromAiJson(json);
      } on InvalidAiOutput catch (e) {
        _log('invalid recognition: ${e.reason}');
        throw RecognitionException(
          RecognitionErrorType.invalidResponse,
          trace: run.finish(
            'invalid',
            notes: [e.reason],
            error: RecognitionErrorType.invalidResponse,
          ),
        );
      }
      final notes = <String>[
        'AI ตอบมา ${result.reportedCount} รายการ',
        if (result.overLimit > 0)
          'เกินขีดจำกัด ${IngredientRecognitionResult.maxIngredients} รายการ: ไม่ได้แสดง ${result.overLimit} รายการ',
        if (result.skipped > 0)
          'ตัดรายการซ้ำ/ผิดรูปแบบ ${result.skipped} รายการ',
      ];
      return RecognitionOutcome(
        result,
        run.finish(result.supported ? 'ok' : 'empty', notes: notes),
      );
    } on RecognitionException catch (e) {
      throw e.trace != null || e.type == RecognitionErrorType.cancelled
          ? e
          : e.withTrace(run.finish(_statusFor(e.type), error: e.type));
    }
  }

  /// ขอให้ AI แนะนำเมนูจากวัตถุดิบที่ผู้ใช้ยืนยันและเงื่อนไขที่เลือก
  /// คืนเฉพาะสูตรที่ผ่านการตรวจ (ไม่เติมสูตรปลอมให้ครบจำนวน)
  Future<SuggestionOutcome> suggestRecipes(
    List<DetectedIngredient> owned, {
    Set<String> kitchen = const {},
    CookingConditions conditions = CookingConditions.standard,
    CancelToken? cancelToken,
  }) async {
    final config = _requireConfig();
    final run = _TraceRun(
      AiTraceKind.suggest,
      config,
      recipePromptVersion,
      'วัตถุดิบ ${owned.length} รายการ, ของในครัว ${kitchen.length} รายการ, '
      '${conditions.summary.join(', ')}',
    );
    try {
      final reply = await _post(
        config,
        {
          'model': config.model,
          'messages': [
            {'role': 'system', 'content': _recipeSystemPrompt},
            {
              'role': 'user',
              'content': recipeUserPrompt(owned, kitchen, conditions),
            },
          ],
          'max_tokens': 6000,
        },
        cancelToken,
        run,
      );

      final json = decodeJsonObject(reply.text);
      final raw = json['recipes'];
      if (raw is! List) {
        throw RecognitionException(
          RecognitionErrorType.invalidResponse,
          trace: run.finish(
            'invalid',
            notes: const ['ไม่มีฟิลด์ recipes ที่เป็นรายการ'],
            error: RecognitionErrorType.invalidResponse,
          ),
        );
      }

      final recipes = <Recipe>[];
      final rejected = <String>[];
      for (var i = 0; i < raw.length; i++) {
        if (recipes.length == recipeCount) {
          rejected.add('สูตรที่ ${i + 1}: เกินจำนวน $recipeCount เมนูที่ขอ');
          continue;
        }
        final parsed = parseAiRecipe(
          raw[i],
          requestedServings: conditions.servings,
        );
        if (parsed.recipe != null) {
          recipes.add(parsed.recipe!);
        } else {
          rejected.add('สูตรที่ ${i + 1}: ${parsed.problem}');
        }
      }
      if (recipes.isEmpty) {
        throw RecognitionException(
          RecognitionErrorType.invalidResponse,
          trace: run.finish(
            'invalid',
            notes: rejected.isEmpty ? const ['ไม่มีสูตรในคำตอบ'] : rejected,
            error: RecognitionErrorType.invalidResponse,
          ),
        );
      }
      return SuggestionOutcome(
        recipes,
        rejected,
        run.finish(
          rejected.isEmpty ? 'ok' : 'partial',
          notes: ['ผ่านการตรวจ ${recipes.length} สูตร', ...rejected],
        ),
      );
    } on RecognitionException catch (e) {
      throw e.trace != null || e.type == RecognitionErrorType.cancelled
          ? e
          : e.withTrace(run.finish(_statusFor(e.type), error: e.type));
    }
  }

  /// ตรวจว่า key/URL/โมเดลใช้งานได้จริง (ส่งคำขอเล็ก ๆ หนึ่งครั้งไปยังปลายทาง)
  Future<AiTrace> testConnection(AiConfig config) async {
    if (!config.hasKey) {
      throw const RecognitionException(RecognitionErrorType.missingApiKey);
    }
    if (validateBaseUrl(config.baseUrl) != null) {
      throw const RecognitionException(RecognitionErrorType.invalidConfig);
    }
    final run = _TraceRun(AiTraceKind.test, config, 'test-v1', 'ข้อความทดสอบ');
    try {
      await _post(
        config,
        {
          'model': config.model,
          'messages': [
            {'role': 'user', 'content': 'Reply with the single word: ok'},
          ],
          'max_tokens': 200,
        },
        null,
        run,
        allowEmpty: true,
        allowTruncated: true,
      );
      return run.finish('ok');
    } on RecognitionException catch (e) {
      throw e.withTrace(run.finish(_statusFor(e.type), error: e.type));
    }
  }

  static String _statusFor(RecognitionErrorType t) => switch (t) {
    RecognitionErrorType.invalidResponse => 'invalid',
    RecognitionErrorType.truncated => 'truncated',
    _ => 'error',
  };

  /// ขีดจำกัดของสูตร AI — เกินแล้ว reject (ไม่ตัดข้อความ/รายการทิ้ง)
  static const maxAiIngredients = 30;
  static const maxAiIngredientName = 80;
  static const maxAiUnit = 30;
  static const maxAiSteps = 20;
  static const maxAiStepChars = 600;
  static const maxAiName = 100;
  static const maxAiDescription = 200;

  /// แปลงและตรวจสูตรหนึ่งรายการจาก AI
  @visibleForTesting
  static AiRecipeParse parseAiRecipe(Object? item, {int? requestedServings}) {
    if (item is! Map) return const AiRecipeParse.rejected('ไม่ใช่ object');
    final rawName = item['name_th'];
    if (rawName is! String || rawName.trim().isEmpty) {
      return const AiRecipeParse.rejected('ไม่มีชื่อเมนู');
    }
    final rawIngredients = item['ingredients'];
    if (rawIngredients is! List) {
      return const AiRecipeParse.rejected('ไม่มีรายการส่วนผสม');
    }
    if (rawIngredients.length > maxAiIngredients) {
      return AiRecipeParse.rejected(
        'ส่วนผสมเกิน $maxAiIngredients รายการ (${rawIngredients.length}) — ไม่ตัดทิ้งเพื่อไม่ให้สูตรไม่ครบ',
      );
    }
    final ingredients = <RecipeIngredient>[];
    for (final i in rawIngredients) {
      if (i is Map) {
        final n = i['name'];
        final u = i['unit'];
        if (n is! String || n.trim().isEmpty) {
          return const AiRecipeParse.rejected(
            'ส่วนผสมบางรายการไม่มีชื่อหรือผิดรูปแบบ',
          );
        }
        if (u != null && u is! String) {
          return const AiRecipeParse.rejected(
            'ส่วนผสมบางรายการมีหน่วยผิดรูปแบบ',
          );
        }
      } else if (i is! String || i.trim().isEmpty) {
        return const AiRecipeParse.rejected('ส่วนผสมบางรายการผิดรูปแบบ');
      }
      final ing = RecipeIngredient.fromJson(i);
      if (ing.name.length > maxAiIngredientName ||
          (ing.unit?.length ?? 0) > maxAiUnit) {
        return const AiRecipeParse.rejected('ชื่อ/หน่วยของส่วนผสมยาวผิดปกติ');
      }
      // ปริมาณที่อ่านไม่ได้/นอกช่วง = ไม่ทราบปริมาณ (ยังเก็บชื่อส่วนผสมไว้)
      final amount = ing.amount;
      ingredients.add(
        RecipeIngredient(
          ing.name,
          ingredientId: ing.ingredientId,
          amount: amount != null && amount > 0 && amount < 100000
              ? amount
              : null,
          unit: ing.unit,
          optional: ing.optional,
        ),
      );
    }
    if (ingredients.length < 2) {
      return const AiRecipeParse.rejected('ส่วนผสมที่ใช้ได้น้อยกว่า 2 รายการ');
    }
    final rawSteps = item['steps'];
    if (rawSteps is! List) {
      return const AiRecipeParse.rejected('ขั้นตอนที่ใช้ได้น้อยกว่า 2 ขั้น');
    }
    final steps = <String>[];
    for (final v in rawSteps) {
      if (v is! String) {
        return const AiRecipeParse.rejected('ขั้นตอนบางข้อผิดรูปแบบ');
      }
      final t = v.trim();
      if (t.isEmpty) continue;
      if (t.length > maxAiStepChars) {
        return AiRecipeParse.rejected(
          'ขั้นตอนยาวเกิน $maxAiStepChars ตัวอักษร — ไม่ตัดกลางประโยค',
        );
      }
      steps.add(t);
    }
    if (steps.length > maxAiSteps) {
      return AiRecipeParse.rejected(
        'ขั้นตอนเกิน $maxAiSteps ข้อ (${steps.length}) — ไม่ตัดทิ้งเพื่อไม่ให้สูตรไม่ครบ',
      );
    }
    if (steps.length < 2) {
      return const AiRecipeParse.rejected('ขั้นตอนที่ใช้ได้น้อยกว่า 2 ขั้น');
    }
    if (rawName.trim().length > maxAiName) {
      return const AiRecipeParse.rejected('ชื่อเมนูยาวผิดปกติ');
    }

    int? n(Object? v, int min, int max) {
      if (v is! num || !v.isFinite) return null;
      // ตรวจช่วงจากค่าต้นทางก่อนปัดเศษ (-0.4 ต้องไม่กลายเป็น 0)
      if (v < min || v > max) return null;
      return v.round();
    }

    // เวลารวมจะ "ทราบ" ก็ต่อเมื่อทั้งเตรียมและทำถูกต้องทั้งคู่ และรวมแล้วไม่เป็น 0
    final prep = n(item['prep_minutes'], 0, 240);
    final cook = n(item['cook_minutes'], 0, 480);
    final timeKnown = prep != null && cook != null && prep + cook > 0;
    final rawEquipment = item['equipment'];
    final spicy = item['spicy'];

    // อุปกรณ์: [] ที่แท้จริง = ไม่ใช้อุปกรณ์; มีค่าที่อ่านไม่ได้ = ไม่ทราบ (ไม่ทิ้งค่านั้นเงียบ ๆ)
    Set<Equipment>? equipment;
    if (rawEquipment is List) {
      final parsed = {for (final e in rawEquipment) Equipment.parse(e)};
      equipment = parsed.contains(null)
          ? null
          : {...parsed.whereType<Equipment>()};
    }

    // วัตถุดิบหลัก = ส่วนผสมแรกที่อยู่ในฐานข้อมูลและไม่ใช่เครื่องปรุง (ใช้กับภาพปก)
    var primary = '';
    for (final i in ingredients) {
      final c = i.catalog;
      if (c != null && !c.pantry) {
        primary = c.id;
        break;
      }
    }
    final description = item['description'];

    return AiRecipeParse.ok(
      Recipe(
        id: 'ai-${_uuid.v4()}',
        nameTh: rawName.trim(),
        description:
            description is String &&
                description.trim().length <= maxAiDescription
            ? description.trim()
            : '',
        primaryIngredientId: primary,
        ingredients: ingredients,
        steps: steps,
        category: RecipeCategory.parse(item['category']),
        difficulty: Difficulty.parse(item['difficulty']),
        prepMinutes: timeKnown ? prep : 0,
        cookMinutes: timeKnown ? cook : 0,
        timeKnown: timeKnown,
        servings: n(item['servings'], 1, 12) ?? requestedServings ?? 2,
        equipment: equipment,
        spicyFlag: spicy is bool ? spicy : null,
        isAiGenerated: true,
      ),
    );
  }

  AiConfig _requireConfig() {
    final config = _config();
    if (!config.hasKey) {
      throw const RecognitionException(RecognitionErrorType.missingApiKey);
    }
    if (validateBaseUrl(config.baseUrl) != null) {
      throw const RecognitionException(RecognitionErrorType.invalidConfig);
    }
    return config;
  }

  /// ดึง JSON object ออกจากข้อความของ AI: ตัด code fence และข้อความก่อน/หลัง JSON
  @visibleForTesting
  static Map<String, dynamic> decodeJsonObject(String content) {
    var s = content
        .replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
        .trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start >= 0 && end > start) s = s.substring(start, end + 1);
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException catch (e) {
      if (kDebugMode) debugPrint('[ApiService] parse error: ${e.message}');
    }
    throw const RecognitionException(RecognitionErrorType.invalidResponse);
  }

  /// ข้อความตอบกลับ: รองรับทั้ง string และรายการ content parts
  static String? _messageText(Object? content) {
    if (content is String) return content.trim();
    if (content is List) {
      final buf = StringBuffer();
      for (final part in content) {
        if (part is Map && part['text'] is String) buf.write(part['text']);
        if (part is String) buf.write(part);
      }
      return buf.toString().trim();
    }
    return null;
  }

  static RecognitionErrorType _typeForStatus(int status) {
    if (status == 401 || status == 403) {
      return RecognitionErrorType.unauthorized;
    }
    if (status == 429) return RecognitionErrorType.rateLimited;
    if (status == 404) return RecognitionErrorType.invalidConfig;
    if (status == 400 || status == 413 || status == 422) {
      return RecognitionErrorType.badRequest;
    }
    return RecognitionErrorType.service;
  }

  Future<_Reply> _post(
    AiConfig config,
    Map<String, dynamic> body,
    CancelToken? cancelToken,
    _TraceRun run, {
    bool allowEmpty = false,
    bool allowTruncated = false,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        chatUrl(config.baseUrl),
        data: body,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer ${config.apiKey}',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
        ),
      );
      run.status = response.statusCode;

      Object? data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          throw const RecognitionException(
            RecognitionErrorType.invalidResponse,
          );
        }
      }
      if (data is! Map) {
        throw const RecognitionException(RecognitionErrorType.invalidResponse);
      }
      final error = data['error'];
      if (error != null) {
        _log('api error field present');
        final code = error is Map
            ? '${error['code']} ${error['type']}'
            : '$error';
        throw RecognitionException(
          code.contains('429') || code.contains('rate')
              ? RecognitionErrorType.rateLimited
              : RecognitionErrorType.service,
        );
      }

      final choices = data['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        throw const RecognitionException(RecognitionErrorType.invalidResponse);
      }
      final first = choices.first as Map;
      final message = first['message'];
      final finish = first['finish_reason'];
      run.finishReason = finish is String ? finish : null;
      final text = message is Map ? _messageText(message['content']) : null;
      run.excerpt = sanitizeForTrace(text ?? '', secret: config.apiKey);

      if (!allowTruncated && run.finishReason == 'length') {
        throw const RecognitionException(RecognitionErrorType.truncated);
      }
      if (text == null || text.isEmpty) {
        if (allowEmpty) return _Reply('', run.finishReason, run.status);
        throw const RecognitionException(RecognitionErrorType.invalidResponse);
      }
      return _Reply(text, run.finishReason, run.status);
    } on RecognitionException {
      rethrow;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      run.status = status;
      _log('dio ${e.type} status=$status');
      switch (e.type) {
        case DioExceptionType.cancel:
          throw const RecognitionException(RecognitionErrorType.cancelled);
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw const RecognitionException(RecognitionErrorType.timeout);
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
          throw const RecognitionException(RecognitionErrorType.network);
        default:
          if (status == null) {
            throw const RecognitionException(RecognitionErrorType.network);
          }
          throw RecognitionException(_typeForStatus(status));
      }
    } on SocketException {
      throw const RecognitionException(RecognitionErrorType.network);
    }
  }

  /// log เฉพาะชนิดเหตุการณ์/สถานะ ไม่ log key, header หรือเนื้อหาคำขอ
  void _log(String message) {
    if (kDebugMode) debugPrint('[ApiService] $message');
  }
}
