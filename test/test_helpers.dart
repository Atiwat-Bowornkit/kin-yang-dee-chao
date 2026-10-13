import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:kinyangdeechao/core/app_scope.dart';
import 'package:kinyangdeechao/data/ai_config_repository.dart';
import 'package:kinyangdeechao/data/favorites_repository.dart';
import 'package:kinyangdeechao/data/history_repository.dart';
import 'package:kinyangdeechao/data/image_store.dart';
import 'package:kinyangdeechao/data/settings_repository.dart';
import 'package:kinyangdeechao/data/shopping_repository.dart';
import 'package:kinyangdeechao/models/ai_trace.dart';
import 'package:kinyangdeechao/models/cooking_conditions.dart';
import 'package:kinyangdeechao/models/ingredient.dart';
import 'package:kinyangdeechao/models/scan_record.dart';
import 'package:kinyangdeechao/models/ingredient_recognition_result.dart';
import 'package:kinyangdeechao/models/recipe.dart';
import 'package:kinyangdeechao/services/api_service.dart';
import 'package:kinyangdeechao/state/ai_config_controller.dart';
import 'package:kinyangdeechao/state/favorites_controller.dart';
import 'package:kinyangdeechao/state/history_controller.dart';
import 'package:kinyangdeechao/state/settings_controller.dart';
import 'package:kinyangdeechao/state/shopping_controller.dart';
import 'package:kinyangdeechao/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// ImageStore ที่ไม่แตะดิสก์ (ใน testWidgets การทำ I/O จริงจะค้าง)
class FakeImageStore extends ImageStore {
  final List<String> saved = [];
  final List<String> deleted = [];

  /// ไฟล์ที่ "มีอยู่" ในโฟลเดอร์ (ใช้ทดสอบ cleanupOrphans)
  final Set<String> files = {};

  @override
  Future<void> init() async {}

  @override
  Future<List<String>> listFiles() async => files.toList()..sort();

  @override
  Future<bool> exists(String? fileName) async =>
      fileName != null && files.contains(fileName);

  @override
  String? pathFor(String? fileName) => fileName == null ? null : 'fake/$fileName';

  @override
  Future<String?> save(XFile image, String id) async {
    saved.add(id);
    return '$id.jpg';
  }

  @override
  Future<void> delete(String? fileName) async {
    if (fileName != null) {
      deleted.add(fileName);
      files.remove(fileName);
    }
  }

  @override
  Future<void> deleteAll() async {}
}

AiTrace fakeTrace(AiTraceKind kind) => AiTrace(
      requestId: 'test',
      kind: kind,
      startedAt: DateTime(2026),
      durationMs: 1200,
      endpoint: 'https://ai.example/v1/chat/completions',
      model: 'test-model',
      promptVersion: 'test',
      inputSummary: 'test',
      parserStatus: 'ok',
    );

/// ApiService ปลอมสำหรับเทสต์หน้าจอ: ควบคุมผลลัพธ์ผ่าน Completer และบันทึกการเรียก
/// (transport/parser จริงทดสอบแยกใน api_service_test.dart ด้วย Dio adapter ปลอม)
class FakeApi extends ApiService {
  FakeApi(super.config);

  Completer<IngredientRecognitionResult> recognize = Completer();
  Completer<List<Recipe>> suggest = Completer();
  CancelToken? lastRecognizeToken;
  CancelToken? lastSuggestToken;
  int recognizeCalls = 0;
  int suggestCalls = 0;
  List<DetectedIngredient>? lastSuggestInput;
  Set<String>? lastSuggestKitchen;
  CookingConditions? lastSuggestConditions;
  Object? testError;

  @override
  Future<RecognitionOutcome> recognizeIngredient(
    XFile image, {
    CancelToken? cancelToken,
  }) async {
    recognizeCalls++;
    lastRecognizeToken = cancelToken;
    final r = await recognize.future;
    return RecognitionOutcome(r, fakeTrace(AiTraceKind.recognize));
  }

  @override
  Future<SuggestionOutcome> suggestRecipes(
    List<DetectedIngredient> owned, {
    Set<String> kitchen = const {},
    CookingConditions conditions = CookingConditions.standard,
    CancelToken? cancelToken,
  }) async {
    suggestCalls++;
    lastSuggestInput = owned;
    lastSuggestKitchen = kitchen;
    lastSuggestConditions = conditions;
    lastSuggestToken = cancelToken;
    final r = await suggest.future;
    return SuggestionOutcome(r, const [], fakeTrace(AiTraceKind.suggest));
  }

  @override
  Future<AiTrace> testConnection(AiConfig config) async {
    if (testError != null) throw testError!;
    return fakeTrace(AiTraceKind.test);
  }
}

/// ชุด controller สำหรับทดสอบ + ตัวห่อ widget ที่มี AppScope และธีมจริงของแอป
class Harness {
  final SharedPreferences prefs;
  final FakeImageStore images;
  final SettingsController settings;
  final HistoryController history;
  final FavoritesController favorites;
  final ShoppingController shopping;
  final AiConfigController ai;
  final FakeApi api;
  final MemorySecretStore secrets;

  Harness._(this.prefs, this.images, this.settings, this.history,
      this.favorites, this.shopping, this.ai, this.api, this.secrets);

  /// [apiKey] = key ที่ผู้ใช้ใส่ไว้แล้ว (null = ยังไม่ได้ตั้งค่า AI)
  static Future<Harness> create([
    Map<String, Object> values = const {},
    String? apiKey = 'test-key',
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final images = FakeImageStore();
    final secrets =
        MemorySecretStore(apiKey == null ? null : {'ai.apiKey': apiKey});
    final ai = AiConfigController(AiConfigRepository(prefs, secrets));
    await ai.load();
    return Harness._(
      prefs,
      images,
      SettingsController(SettingsRepository(prefs)),
      HistoryController(HistoryRepository(prefs), images),
      FavoritesController(FavoritesRepository(prefs)),
      ShoppingController(ShoppingRepository(prefs)),
      ai,
      FakeApi(() => ai.config),
      secrets,
    );
  }

  /// ทำให้การเขียน SharedPreferences ทุกครั้งหลังจากนี้ล้มเหลว (เช่น ดิสก์เต็ม)
  void failWrites() {
    SharedPreferencesStorePlatform.instance = _FailingStore();
    secrets.failWrites = true;
  }

  AppScopeData get data => AppScopeData(
        settings: settings,
        history: history,
        favorites: favorites,
        shopping: shopping,
        ai: ai,
        images: images,
        api: api,
      );

  Widget wrap(Widget child, {ThemeMode mode = ThemeMode.light}) => AppScope(
        data: data,
        child: MaterialApp(
          theme: lightAppTheme,
          darkTheme: darkAppTheme,
          themeMode: mode,
          locale: const Locale('th', 'TH'),
          supportedLocales: const [Locale('th', 'TH'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: child,
        ),
      );
}

const egg = DetectedIngredient(id: 'egg', nameTh: 'ไข่ไก่', emoji: '🥚', known: true);
const tomato =
    DetectedIngredient(id: 'tomato', nameTh: 'มะเขือเทศ', emoji: '🍅', known: true);
const pork = DetectedIngredient(id: 'pork', nameTh: 'หมู', emoji: '🥩', known: true);

/// จอมือถือขนาดจริง (360×640 dp) — ปุ่มที่อยู่ต่ำกว่าจอต้องเลื่อนถึงด้วย scrollUntilVisible
void usePhone(WidgetTester tester, {Size size = const Size(360, 640)}) {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// เลื่อนรายการหลักของหน้าจนเห็น [finder] แล้วแตะ
Future<void> scrollAndTap(WidgetTester tester, Finder finder,
    {Finder? scrollable}) async {
  await tester.scrollUntilVisible(finder, 200,
      scrollable: scrollable ?? find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// เลื่อนรายการหลักของหน้าจนเห็น [finder] (ถ้ายังไม่ถูกสร้าง/อยู่นอกจอ)
Future<void> seeVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// เลื่อนให้เห็นแล้วแตะ (ใช้กับจอ 360x640 แทนการขยาย viewport)
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await seeVisible(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// รายการที่ยืนยันแล้ว (สำหรับเทสต์หน้าผลลัพธ์)
ScanRecord confirmedRecord(
  String id,
  List<DetectedIngredient> items, {
  Set<String> kitchen = const {'oil', 'fish_sauce', 'soy_sauce', 'sugar', 'salt', 'water'},
  CookingConditions conditions = CookingConditions.standard,
  bool manual = true,
  String? imageFile,
}) =>
    ScanRecord(
      id: id,
      createdAt: DateTime.now(),
      ingredients: items,
      detected: manual ? const [] : items,
      manual: manual,
      imageFile: imageFile,
      status: ScanStatus.confirmed,
      confirmedAt: DateTime.now(),
      kitchen: kitchen,
      conditions: conditions,
    );

/// Directory ชั่วคราวสำหรับเทสต์ที่ต้องใช้ไฟล์จริง (ใช้กับ test() ธรรมดาเท่านั้น)
Directory makeTempDir() => Directory.systemTemp.createTempSync('kyd_test_');

class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async => false;

  @override
  Future<bool> remove(String key) async => false;
}
