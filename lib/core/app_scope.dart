import 'package:flutter/widgets.dart';

import '../data/image_store.dart';
import '../services/api_service.dart';
import '../state/ai_config_controller.dart';
import '../state/favorites_controller.dart';
import '../state/history_controller.dart';
import '../state/settings_controller.dart';
import '../state/shopping_controller.dart';

/// รวม state ของแอปให้เข้าถึงได้จากทุกหน้าผ่าน context
class AppScope extends StatelessWidget {
  final AppScopeData data;
  final Widget child;

  const AppScope({super.key, required this.data, required this.child});

  /// อ่านพร้อมสมัครรับการเปลี่ยนแปลง (หน้าจะ rebuild เมื่อข้อมูลเปลี่ยน)
  static AppScopeData of(BuildContext context) {
    final data = context.dependOnInheritedWidgetOfExactType<_ScopeInherited>();
    assert(data != null, 'ไม่พบ AppScope ใน widget tree');
    return data!.data;
  }

  /// อ่านครั้งเดียวโดยไม่สมัครรับ (ใช้ใน callback/initState)
  static AppScopeData read(BuildContext context) {
    final data = context.getInheritedWidgetOfExactType<_ScopeInherited>();
    assert(data != null, 'ไม่พบ AppScope ใน widget tree');
    return data!.data;
  }

  @override
  Widget build(BuildContext context) {
    // child เป็น instance เดิม → rebuild เฉพาะ widget ที่เรียก AppScope.of
    return ListenableBuilder(
      listenable: Listenable.merge([
        data.settings,
        data.history,
        data.favorites,
        data.shopping,
        data.ai,
      ]),
      builder: (_, _) => _ScopeInherited(data: data, child: child),
    );
  }
}

class AppScopeData {
  final SettingsController settings;
  final HistoryController history;
  final FavoritesController favorites;
  final ShoppingController shopping;
  final AiConfigController ai;
  final ImageStore images;
  final ApiService api;

  const AppScopeData({
    required this.settings,
    required this.history,
    required this.favorites,
    required this.shopping,
    required this.ai,
    required this.images,
    required this.api,
  });
}

class _ScopeInherited extends InheritedWidget {
  final AppScopeData data;

  const _ScopeInherited({required this.data, required super.child});

  @override
  bool updateShouldNotify(_ScopeInherited oldWidget) => true;
}
