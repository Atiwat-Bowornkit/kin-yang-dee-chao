import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_record.dart';

class HistoryRepository {
  HistoryRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'history.v1';

  /// ข้อมูลเสียหาย → ข้ามรายการนั้น (ไม่ทำให้แอปล่ม)
  List<ScanRecord> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final out = <ScanRecord>[];
      for (final item in list) {
        try {
          out.add(ScanRecord.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (_) {}
      }
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('HistoryRepository.load failed: $e');
      return [];
    }
  }

  /// คืน false เมื่อเขียนลงเครื่องไม่สำเร็จ
  Future<bool> save(List<ScanRecord> records) =>
      _prefs.setString(_key, jsonEncode([for (final r in records) r.toJson()]));

  // ---- ผลสแกนที่ยังไม่ยืนยัน (แยกจากประวัติ เก็บได้ครั้งละ 1 รายการ) ----
  static const _draftKey = 'history.draft.v1';

  ScanRecord? loadDraft() {
    final raw = _prefs.getString(_draftKey);
    if (raw == null) return null;
    try {
      final r = ScanRecord.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      return r.copyWith(status: ScanStatus.draft);
    } catch (e) {
      if (kDebugMode) debugPrint('HistoryRepository.loadDraft failed: $e');
      return null;
    }
  }

  Future<bool> saveDraft(ScanRecord? draft) => draft == null
      ? _prefs.remove(_draftKey)
      : _prefs.setString(_draftKey, jsonEncode(draft.toJson()));
}
