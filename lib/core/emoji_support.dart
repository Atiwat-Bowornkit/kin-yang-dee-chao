import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// emoji รุ่นใหม่บางตัวแสดงเป็นกล่องว่างบน Android รุ่นเก่า (เช่น Android 9)
/// จึงเลือกตัวแทนที่แสดงได้ตามระดับ API ของเครื่อง
///
/// ระดับ API ขั้นต่ำที่ฟอนต์ระบบมี emoji นั้น: Emoji 12 → 29, 13 → 30, 14 → 33, 15 → 34
class EmojiSupport {
  EmojiSupport._();

  static const _channel = MethodChannel('app.kinyangdeechao/platform');

  /// null = ไม่ใช่ Android หรืออ่านค่าไม่ได้ → ถือว่ารองรับทั้งหมด
  static int? _sdk;

  @visibleForTesting
  static set sdkForTesting(int? v) => _sdk = v;

  static Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      _sdk = await _channel.invokeMethod<int>('sdkInt');
    } catch (_) {
      _sdk = null;
    }
  }

  /// emoji → (API ขั้นต่ำ, ตัวแทนสำหรับเครื่องเก่า)
  static const _table = <String, (int, String)>{
    '🧄': (29, '🌰'),
    '🧅': (29, '🌰'),
    '🧈': (29, '🧀'),
    '🧊': (29, '⬜'),
    '🫑': (30, '🌶️'),
    '🫙': (33, '🍶'),
    '🫗': (33, '🍶'),
    '🫚': (34, '🌿'),
    '🫛': (34, '🥒'),
  };

  static String display(String emoji) {
    final sdk = _sdk;
    if (sdk == null) return emoji;
    final e = _table[emoji];
    return e != null && sdk < e.$1 ? e.$2 : emoji;
  }
}

/// emoji ที่แสดงได้บนเครื่องนี้ (ใช้ทุกจุดที่วาด emoji วัตถุดิบ)
String safeEmoji(String emoji) => EmojiSupport.display(emoji);
