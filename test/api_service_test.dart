import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:kinyangdeechao/models/ai_trace.dart';
import 'package:kinyangdeechao/models/cooking_conditions.dart';
import 'package:kinyangdeechao/services/api_service.dart';
import 'package:kinyangdeechao/state/ai_config_controller.dart';

import 'test_helpers.dart';

const _secret = 'sk-test-SECRET-0123456789abcdef';
const _https = AiConfig(
    apiKey: _secret, baseUrl: 'https://ai.example/v1', model: 'vision-model');

/// Dio adapter ปลอม: ส่งคำตอบที่กำหนด และเก็บคำขอไว้ตรวจ (ไม่ออกเน็ตจริง)
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  ResponseBody Function(RequestOptions o) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// คำตอบแบบ OpenAI-compatible
ResponseBody _chat(Object? content, {String finish = 'stop'}) => _json({
      'choices': [
        {
          'message': {'role': 'assistant', 'content': content},
          'finish_reason': finish,
        },
      ],
    });

({ApiService api, _FakeAdapter adapter}) _make(
  ResponseBody Function(RequestOptions o) respond, {
  AiConfig config = _https,
}) {
  final adapter = _FakeAdapter(respond);
  final dio = Dio()..httpClientAdapter = adapter;
  return (api: ApiService(() => config, dio: dio), adapter: adapter);
}

Matcher _throwsType(RecognitionErrorType t) => throwsA(
    isA<RecognitionException>().having((e) => e.type, 'type', t));

/// trace ต้องไม่มี key, header หรือรูป base64
void _expectClean(AiTrace? t) {
  expect(t, isNotNull);
  final s = jsonEncode(t!.toJson());
  expect(s, isNot(contains(_secret)));
  expect(s, isNot(contains('Bearer')));
  expect(s, isNot(contains('base64,')));
  expect(t.endpoint, 'https://ai.example/v1/chat/completions');
}

void main() {
  late Directory dir;
  late XFile image;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kyd_api_');
    final f = File('${dir.path}/photo.jpg')..writeAsBytesSync(List.filled(2048, 7));
    image = XFile(f.path);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('recognizeIngredient', () {
    test('parses fenced JSON, sends key only in the header over https', () async {
      final s = _make((_) => _chat(
          'ผลลัพธ์:\n```json\n{"ingredients":[{"id":"egg"},{"name_th":"ไข่เค็ม"}]}\n```'));
      final out = await s.api.recognizeIngredient(image);

      expect(out.result.ingredients.map((i) => i.nameTh), ['ไข่ไก่', 'ไข่เค็ม']);
      final req = s.adapter.requests.single;
      expect(req.uri.toString(), 'https://ai.example/v1/chat/completions');
      expect(req.headers[HttpHeaders.authorizationHeader], 'Bearer $_secret');
      final body = jsonEncode(req.data);
      expect(body, contains('data:image/jpeg;base64,'));
      expect(body, isNot(contains(_secret)), reason: 'key ต้องไม่อยู่ใน body');
      expect(out.trace.httpStatus, 200);
      expect(out.trace.parserStatus, 'ok');
      expect(out.trace.promptVersion, ApiService.recognitionPromptVersion);
      _expectClean(out.trace);
    });

    test('accepts content as a list of text parts', () async {
      final s = _make((_) => _chat([
            {'type': 'text', 'text': '{"ingredients":'},
            {'type': 'text', 'text': '["tomato"]}'},
          ]));
      final out = await s.api.recognizeIngredient(image);
      expect(out.result.knownIds, ['tomato']);
    });

    test('malformed JSON → invalidResponse with a clean trace', () async {
      final s = _make((_) => _chat('ขอโทษ ฉันไม่เห็นภาพ'));
      try {
        await s.api.recognizeIngredient(image);
        fail('should throw');
      } on RecognitionException catch (e) {
        expect(e.type, RecognitionErrorType.invalidResponse);
        expect(e.trace!.parserStatus, 'invalid');
        _expectClean(e.trace);
      }
    });

    test('wrong field types → invalidResponse (not a crash)', () async {
      for (final content in [
        '{"ingredients":"egg"}',
        '{"items":["egg"]}',
        '{"ingredients":[1,2,3]}',
      ]) {
        final s = _make((_) => _chat(content));
        await expectLater(s.api.recognizeIngredient(image),
            _throwsType(RecognitionErrorType.invalidResponse),
            reason: content);
      }
    });

    test('empty list is a valid "nothing found" result', () async {
      final s = _make((_) => _chat('{"ingredients":[]}'));
      final out = await s.api.recognizeIngredient(image);
      expect(out.result.ingredients, isEmpty);
      expect(out.trace.parserStatus, 'empty');
    });

    test('finish_reason=length → truncated (not a partial result)', () async {
      final s = _make((_) => _chat('{"ingredients":["egg"', finish: 'length'));
      try {
        await s.api.recognizeIngredient(image);
        fail('should throw');
      } on RecognitionException catch (e) {
        expect(e.type, RecognitionErrorType.truncated);
        expect(e.trace!.finishReason, 'length');
      }
    });

    test('over-limit items are counted in the trace notes', () async {
      final s = _make((_) => _chat(jsonEncode({
            'ingredients': [for (var i = 0; i < 15; i++) 'ผัก$i'],
          })));
      final out = await s.api.recognizeIngredient(image);
      expect(out.result.overLimit, 3);
      expect(out.trace.notes.join(' '), contains('ไม่ได้แสดง 3 รายการ'));
    });

    test('HTTP status codes map to error categories', () async {
      final cases = {
        401: RecognitionErrorType.unauthorized,
        403: RecognitionErrorType.unauthorized,
        429: RecognitionErrorType.rateLimited,
        404: RecognitionErrorType.invalidConfig,
        400: RecognitionErrorType.badRequest,
        413: RecognitionErrorType.badRequest,
        500: RecognitionErrorType.service,
        503: RecognitionErrorType.service,
      };
      for (final e in cases.entries) {
        final s = _make((_) => _json({
              'error': {'message': 'echo $_secret'},
            }, status: e.key));
        try {
          await s.api.recognizeIngredient(image);
          fail('should throw for ${e.key}');
        } on RecognitionException catch (x) {
          expect(x.type, e.value, reason: '${e.key}');
          expect(x.trace!.httpStatus, e.key);
          _expectClean(x.trace);
        }
      }
    });

    test('an error object inside a 200 response is not treated as success', () async {
      final s = _make((_) => _json({
            'error': {'code': 429, 'type': 'rate_limit'},
          }));
      await expectLater(s.api.recognizeIngredient(image),
          _throwsType(RecognitionErrorType.rateLimited));
    });

    test('timeouts and connection errors', () async {
      final t = _make((o) => throw DioException(
          requestOptions: o, type: DioExceptionType.receiveTimeout));
      await expectLater(
          t.api.recognizeIngredient(image), _throwsType(RecognitionErrorType.timeout));
      final n = _make((o) => throw DioException(
          requestOptions: o, type: DioExceptionType.connectionError));
      await expectLater(
          n.api.recognizeIngredient(image), _throwsType(RecognitionErrorType.network));
    });

    test('a cancelled request reports cancelled', () async {
      final s = _make((_) => _chat('{"ingredients":["egg"]}'));
      final token = CancelToken()..cancel();
      await expectLater(s.api.recognizeIngredient(image, cancelToken: token),
          _throwsType(RecognitionErrorType.cancelled));
    });

    test('missing key / non-https URL never send a request', () async {
      final noKey = _make((_) => _chat('{}'),
          config: const AiConfig(apiKey: '', baseUrl: 'https://ai.example/v1', model: 'm'));
      await expectLater(noKey.api.recognizeIngredient(image),
          _throwsType(RecognitionErrorType.missingApiKey));
      expect(noKey.adapter.requests, isEmpty);

      final http = _make((_) => _chat('{}'),
          config: const AiConfig(apiKey: _secret, baseUrl: 'http://ai.example/v1', model: 'm'));
      await expectLater(http.api.recognizeIngredient(image),
          _throwsType(RecognitionErrorType.invalidConfig));
      expect(http.adapter.requests, isEmpty, reason: 'ไม่ส่ง key ผ่าน http');
    });

    test('an image over the size limit is rejected before upload', () async {
      final big = File('${dir.path}/big.jpg')
        ..writeAsBytesSync(Uint8List(ApiService.maxImageBytes + 1));
      final s = _make((_) => _chat('{}'));
      await expectLater(s.api.recognizeIngredient(XFile(big.path)),
          _throwsType(RecognitionErrorType.imageTooLarge));
      expect(s.adapter.requests, isEmpty);
    });

    test('PNG files are sent with their own MIME type', () async {
      final png = File('${dir.path}/shot.png')..writeAsBytesSync([1, 2, 3]);
      final s = _make((_) => _chat('{"ingredients":["egg"]}'));
      await s.api.recognizeIngredient(XFile(png.path));
      expect(jsonEncode(s.adapter.requests.single.data),
          contains('data:image/png;base64,'));
    });
  });

  group('validateBaseUrl', () {
    test('https only, except local development hosts', () {
      expect(ApiService.validateBaseUrl('https://api.example.com/v1'), isNull);
      expect(ApiService.validateBaseUrl('http://10.0.2.2:8080/v1'), isNull);
      expect(ApiService.validateBaseUrl('http://api.example.com/v1'), isNotNull);
      expect(ApiService.validateBaseUrl('https://u:p@api.example.com'), isNotNull);
      expect(ApiService.validateBaseUrl('https://api.example.com/v1?key=1'), isNotNull);
      expect(ApiService.validateBaseUrl('ไม่ใช่ url'), isNotNull);
    });
  });

  group('suggestRecipes', () {
    Map<String, Object?> recipe(String name) => {
          'name_th': name,
          'prep_minutes': 5,
          'cook_minutes': 10,
          'servings': 3,
          'spicy': false,
          'equipment': ['pan'],
          'ingredients': [
            {'name': 'ไข่ไก่', 'amount': 3, 'unit': 'ฟอง'},
            {'name': 'มะเขือเทศ', 'amount': 2, 'unit': 'ลูก'},
          ],
          'steps': ['ตอกไข่', 'ผัด'],
        };

    test('sends confirmed items, kitchen and conditions; keeps valid recipes only',
        () async {
      final s = _make((_) => _chat(jsonEncode({
            'recipes': [
              recipe('ไข่ผัดมะเขือเทศ'),
              {'name_th': 'สูตรพัง', 'ingredients': 'ไข่'},
              recipe('ไข่คนมะเขือเทศ'),
            ],
          })));
      final out = await s.api.suggestRecipes(
        const [egg, tomato],
        kitchen: {'oil'},
        conditions: const CookingConditions(
            maxMinutes: 15, servings: 3, spice: SpicePreference.mild),
      );
      expect(out.recipes.map((r) => r.nameTh), ['ไข่ผัดมะเขือเทศ', 'ไข่คนมะเขือเทศ']);
      expect(out.rejected.single, startsWith('สูตรที่ 2'));
      expect(out.trace.parserStatus, 'partial');
      expect(out.recipes.first.equipment, {Equipment.pan});

      final prompt = jsonEncode(s.adapter.requests.single.data);
      expect(prompt, contains('ไข่ไก่, มะเขือเทศ'));
      expect(prompt, contains('ไม่เกิน 15 นาที'));
      expect(prompt, contains('3 ที่'));
      expect(prompt, contains('ต้องไม่เผ็ด'));
      expect(prompt, contains('น้ำมัน'));
      _expectClean(out.trace);
    });

    test('never pads to 3 and never exceeds 3', () async {
      final one = _make((_) => _chat(jsonEncode({'recipes': [recipe('a')]})));
      expect((await one.api.suggestRecipes(const [egg])).recipes.length, 1);

      final many = _make((_) => _chat(jsonEncode({
            'recipes': [for (var i = 0; i < 5; i++) recipe('r$i')],
          })));
      final out = await many.api.suggestRecipes(const [egg]);
      expect(out.recipes.length, ApiService.recipeCount);
      expect(out.rejected.length, 2);
    });

    test('no valid recipe → invalidResponse with reasons in the trace', () async {
      final s = _make((_) => _chat(jsonEncode({
            'recipes': [
              {'name_th': 'x', 'ingredients': ['ไข่'], 'steps': ['a']},
            ],
          })));
      try {
        await s.api.suggestRecipes(const [egg]);
        fail('should throw');
      } on RecognitionException catch (e) {
        expect(e.type, RecognitionErrorType.invalidResponse);
        expect(e.trace!.notes.single, contains('สูตรที่ 1'));
      }
    });

    test('missing recipes field → invalidResponse', () async {
      final s = _make((_) => _chat('{"menu":[]}'));
      await expectLater(s.api.suggestRecipes(const [egg]),
          _throwsType(RecognitionErrorType.invalidResponse));
    });
  });

  group('testConnection', () {
    test('success returns a sanitized trace with status and duration', () async {
      final s = _make((_) => _chat('ok'));
      final t = await s.api.testConnection(_https);
      expect(t.kind, AiTraceKind.test);
      expect(t.httpStatus, 200);
      expect(t.durationMs, greaterThanOrEqualTo(0));
      _expectClean(t);
    });

    test('401 is reported as unauthorized', () async {
      final s = _make((_) => _json({'error': 'bad key'}, status: 401));
      await expectLater(
          s.api.testConnection(_https), _throwsType(RecognitionErrorType.unauthorized));
    });
  });

  group('sanitizeForTrace', () {
    test('removes secrets, bearer tokens, key-like strings and images', () {
      final s = sanitizeForTrace(
        'key=$_secret Authorization: Bearer abc.def-123 sk-live-zzzzzzzzzzzzzzzzzzzz '
        'data:image/png;base64,${'A' * 400}',
        secret: _secret,
      );
      expect(s, isNot(contains(_secret)));
      expect(s, isNot(contains('abc.def-123')));
      expect(s, isNot(contains('sk-live')));
      expect(s, isNot(contains('AAAAAAAA')));
      expect(sanitizeForTrace('x' * 5000).length, lessThanOrEqualTo(1501));
    });

    test('endpoint keeps only scheme, host and path', () {
      expect(sanitizeEndpoint('https://u:p@ai.example:8443/v1/chat?key=1#x'),
          'https://ai.example:8443/v1/chat');
    });
  });
}
