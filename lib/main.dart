import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/app_scope.dart';
import 'data/ai_config_repository.dart';
import 'data/favorites_repository.dart';
import 'data/history_repository.dart';
import 'data/image_store.dart';
import 'data/settings_repository.dart';
import 'data/shopping_repository.dart';
import 'services/api_service.dart';
import 'state/ai_config_controller.dart';
import 'state/favorites_controller.dart';
import 'state/history_controller.dart';
import 'state/settings_controller.dart';
import 'state/shopping_controller.dart';
import 'core/emoji_support.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final images = ImageStore();
  final ai = AiConfigController(
    AiConfigRepository(prefs, const SecureSecretStore()),
  );
  await Future.wait([images.init(), ai.load(), EmojiSupport.init()]);

  final history = HistoryController(HistoryRepository(prefs), images);
  runApp(
    KinYangDeeChaoApp(
      data: AppScopeData(
        settings: SettingsController(SettingsRepository(prefs)),
        history: history,
        favorites: FavoritesController(FavoritesRepository(prefs)),
        shopping: ShoppingController(ShoppingRepository(prefs)),
        ai: ai,
        images: images,
        api: ApiService(() => ai.config),
      ),
    ),
  );
  // ลบรูปที่ไม่มีรายการใดอ้างถึง (เช่น แอปถูกปิดระหว่างวิเคราะห์) — ทำหลังแสดงหน้าแรก
  history.cleanupOrphans();
}
