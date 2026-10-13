import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/history_repository.dart';
import '../data/image_store.dart';
import '../models/ai_trace.dart';
import '../models/cooking_conditions.dart';
import '../models/ingredient.dart';
import '../models/scan_record.dart';

/// ประวัติการสแกนที่ยืนยันแล้ว/ข้อมูลเก่า + ผลสแกนที่ยังไม่ยืนยัน (draft) แยกกัน
///
/// หลักการเรื่องข้อมูลถาวร:
/// - [_durableRecords]/[_durableDraft] คือสิ่งที่เขียนลงเครื่องสำเร็จครั้งล่าสุดจริง ๆ
///   (แยกจาก state ในหน่วยความจำ)
/// - ไฟล์รูปจะถูกลบก็ต่อเมื่อไม่มีทั้งข้อมูลในหน่วยความจำและข้อมูลถาวรอ้างถึงแล้วเท่านั้น
///   ดังนั้นเขียน/ลบ key ไม่สำเร็จ = รูปยังอยู่ ข้อมูลที่กู้คืนได้ยังครบ
/// - ทุกเมธอดที่เปลี่ยนข้อมูลคืนผลลัพธ์ให้ UI (true = บันทึกลงเครื่องสำเร็จ) ไม่พึ่ง log
class HistoryController extends ChangeNotifier {
  HistoryController(this._repo, this._images)
    : _records = _repo.load(),
      _draft = _repo.loadDraft() {
    _durableRecords = List.of(_records);
    _durableDraft = _draft;
    // ร่างที่ถูกยืนยันไปแล้วแต่ลบ key ร่างไม่สำเร็จ (เขียนไม่ครบ) → ฉบับที่ยืนยันแล้วชนะ ไม่ให้ซ้ำ
    final d = _draft;
    if (d != null && _records.any((r) => r.id == d.id)) _draft = null;
  }

  static const maxRecords = 100;

  final HistoryRepository _repo;
  final ImageStore _images;

  final List<ScanRecord> _records; // ใหม่สุดอยู่ก่อน
  ScanRecord? _draft;

  /// สถานะที่เขียนลงเครื่องสำเร็จล่าสุด
  List<ScanRecord> _durableRecords = const [];
  ScanRecord? _durableDraft;

  /// รายการที่ถูกลบแต่ยังเลิกทำได้ (แยกตาม id — ลบหลายรายการติดกันได้โดยไม่ปนกัน)
  final Map<String, ({ScanRecord record, int index})> _pending = {};

  /// เพิ่มทุกครั้งที่รายการถูกคืนกลับหลังลบไม่สำเร็จ — UI ใช้ประกอบ key ของ Dismissible
  /// (Dismissible ที่ปัดทิ้งแล้วห้ามกลับเข้าต้นไม้ด้วย key เดิมก่อนเฟรมถัดไป)
  final Map<String, int> _restores = {};
  int restoreEpoch(String id) => _restores[id] ?? 0;

  /// ไฟล์รูปที่ไม่ต้องใช้แล้ว รอลบเมื่อไม่มีข้อมูลใดอ้างถึง
  final Set<String> _garbage = {};

  /// true เมื่อการบันทึกครั้งล่าสุดล้มเหลว
  bool lastSaveFailed = false;

  List<ScanRecord> get records => List.unmodifiable(_records);
  bool get isEmpty => _records.isEmpty;

  /// ผลสแกนที่ยังไม่ยืนยัน (ไม่อยู่ในประวัติ)
  ScanRecord? get draft => _draft;

  ScanRecord? byId(String id) {
    if (_draft?.id == id) return _draft;
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ---------------- เขียนลงเครื่อง ----------------

  Future<void> _tail = Future.value();

  /// เรียงลำดับการเขียนให้เหมือนลำดับที่สั่ง (ผลสุดท้ายตรงกับสถานะล่าสุดเสมอ)
  Future<T> _serial<T>(Future<T> Function() op) {
    final c = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        c.complete(await op());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  Future<bool> _persist() => _serial(() async {
    final snapshot = List<ScanRecord>.of(_records);
    var ok = false;
    try {
      ok = await _repo.save(snapshot);
    } catch (e) {
      if (kDebugMode) debugPrint('HistoryController save failed: $e');
    }
    if (ok) _durableRecords = snapshot;
    lastSaveFailed = !ok;
    return ok;
  });

  Future<bool> _persistDraft() => _serial(() async {
    final snapshot = _draft;
    var ok = false;
    try {
      ok = await _repo.saveDraft(snapshot);
    } catch (e) {
      if (kDebugMode) debugPrint('HistoryController draft save failed: $e');
    }
    if (ok) _durableDraft = snapshot;
    return ok;
  });

  // ---------------- ไฟล์รูป ----------------

  Set<String> _referenced() => {
    for (final r in _records) ?r.imageFile,
    for (final r in _durableRecords) ?r.imageFile,
    for (final p in _pending.values) ?p.record.imageFile,
    ?_draft?.imageFile,
    ?_durableDraft?.imageFile,
  };

  void _release(Iterable<String?> files) {
    for (final f in files) {
      if (f != null) _garbage.add(f);
    }
  }

  /// ลบเฉพาะรูปที่ไม่มีข้อมูลใด (รวมข้อมูลถาวรที่เขียนสำเร็จล่าสุด) อ้างถึง
  Future<void> _sweep() async {
    final keep = _referenced();
    for (final f in _garbage.toList()) {
      if (keep.contains(f)) continue;
      _garbage.remove(f);
      await _images.delete(f);
    }
  }

  /// เพิ่มรายการที่ยืนยันแล้ว (เช่น เลือกวัตถุดิบเอง) คืน false ถ้าบันทึกไม่สำเร็จ
  Future<bool> add(ScanRecord record) async {
    _records.insert(0, record);
    final overflow = <ScanRecord>[];
    while (_records.length > maxRecords) {
      overflow.add(_records.removeLast());
    }
    notifyListeners();
    final ok = await _persist();
    _release(overflow.map((r) => r.imageFile));
    await _sweep();
    return ok;
  }

  // ---------------- draft ----------------

  /// เก็บผลสแกนใหม่ที่ยังไม่ยืนยัน (แทน draft เดิมและลบรูปของ draft เดิมเมื่อปลอดภัย)
  Future<bool> saveDraft(ScanRecord draft) async {
    final old = _draft;
    _draft = draft.copyWith(status: ScanStatus.draft);
    notifyListeners();
    final ok = await _persistDraft();
    if (old != null && old.id != draft.id && old.imageFile != draft.imageFile) {
      _release([old.imageFile]);
    }
    await _sweep();
    return ok;
  }

  /// แก้ draft ระหว่างตรวจ (เก็บไว้กู้คืนได้ถ้าแอปถูกปิด) คืน false ถ้าบันทึกไม่สำเร็จ
  Future<bool> updateDraft(ScanRecord draft) async {
    if (_draft?.id != draft.id) return false;
    _draft = draft.copyWith(status: ScanStatus.draft);
    notifyListeners();
    return _persistDraft();
  }

  /// ทิ้งผลสแกนที่ยังไม่ยืนยัน พร้อมลบรูปที่แอปเก็บไว้
  /// เขียนไม่สำเร็จ → draft กลับมาและรูปยังอยู่ (คืน false)
  Future<bool> discardDraft() async {
    final d = _draft;
    if (d == null) return true;
    _draft = null;
    notifyListeners();
    final ok = await _persistDraft();
    if (!ok) {
      _draft ??= d;
      notifyListeners();
      return false;
    }
    _release([d.imageFile]);
    await _sweep();
    return true;
  }

  /// ยืนยันวัตถุดิบ: draft → ประวัติ, legacy/confirmed → อัปเดตรายการเดิม
  /// ถ้ารายการวัตถุดิบหรือของในครัวเปลี่ยน สูตร AI เดิมจะยังเก็บไว้แต่ถูกแสดงเป็น "ผลเก่า"
  ///
  /// draft: เขียนประวัติก่อน แล้วจึงลบ key ของ draft — ถ้าเขียนประวัติไม่สำเร็จ จะคืน false
  /// และ draft ยังอยู่ครบทั้งในหน่วยความจำและในเครื่อง (ยืนยันใหม่ได้)
  Future<bool> confirm(
    String id, {
    required List<DetectedIngredient> ingredients,
    required List<IngredientRename> renames,
    required Set<String> kitchen,
  }) async {
    final now = DateTime.now();
    final d = _draft;
    if (d != null && d.id == id) {
      final confirmed = d.copyWith(
        status: ScanStatus.confirmed,
        ingredients: ingredients,
        renames: renames,
        kitchen: kitchen,
        confirmedAt: now,
      );
      final before = List<ScanRecord>.of(_records);
      _records.insert(0, confirmed);
      final overflow = <ScanRecord>[];
      while (_records.length > maxRecords) {
        overflow.add(_records.removeLast());
      }
      notifyListeners();
      if (!await _persist()) {
        _records
          ..clear()
          ..addAll(before);
        notifyListeners();
        return false;
      }
      _draft = null;
      notifyListeners();
      // ลบ key ของ draft ไม่สำเร็จ: ในเครื่องมีทั้ง draft และฉบับยืนยัน → ตอนโหลดฉบับยืนยันชนะ
      // (รูปของ draft คือรูปเดียวกับรายการนี้ จึงยังถูกอ้างถึงและไม่ถูกลบ)
      await _persistDraft();
      _release(overflow.map((r) => r.imageFile));
      await _sweep();
      return true;
    }
    final i = _records.indexWhere((r) => r.id == id);
    if (i < 0) return false;
    final old = _records[i];
    _records[i] = old.copyWith(
      status: ScanStatus.confirmed,
      ingredients: ingredients,
      renames: renames,
      kitchen: kitchen,
      confirmedAt: now,
    );
    notifyListeners();
    final ok = await _persist();
    if (!ok) {
      final j = _records.indexWhere((r) => r.id == id);
      if (j >= 0) _records[j] = old;
      notifyListeners();
    }
    return ok;
  }

  // ---------------- อัปเดตรายการในประวัติ ----------------

  Future<bool> _update(
    String id,
    ScanRecord Function(ScanRecord) change,
  ) async {
    if (_draft?.id == id) {
      _draft = change(_draft!);
      notifyListeners();
      return _persistDraft();
    }
    final i = _records.indexWhere((r) => r.id == id);
    if (i < 0) return false;
    _records[i] = change(_records[i]);
    notifyListeners();
    return _persist();
  }

  Future<bool> updateConditions(String id, CookingConditions c) =>
      _update(id, (r) => r.copyWith(conditions: c));

  /// เก็บสูตร AI พร้อมคีย์ของ input ที่ใช้ขอ
  Future<bool> saveAiRecipes(
    String id,
    AiRecipeCache cache, {
    AiTrace? trace,
  }) => _update(id, (r) {
    final next = r.copyWith(ai: cache);
    return trace == null ? next : next.withTrace(trace);
  });

  Future<bool> addTrace(String id, AiTrace trace) =>
      _update(id, (r) => r.withTrace(trace));

  // ---------------- ลบ / เลิกทำ ----------------

  /// ลบแบบ "เลิกทำได้": เอาออกจากรายการทันที (ส่วน sync ทำก่อน await แรก) แต่เก็บไฟล์รูปไว้จนกว่าจะ [finalizeRemoval]
  /// เขียนไม่สำเร็จ → รายการกลับมา (คืน false) เพื่อไม่ให้ดูเหมือนลบแล้วทั้งที่ยังอยู่ในเครื่อง
  Future<bool> remove(String id) async {
    final i = _records.indexWhere((r) => r.id == id);
    if (i < 0) return true;
    _pending[id] = (record: _records.removeAt(i), index: i);
    notifyListeners();
    final ok = await _persist();
    if (!ok) {
      final p = _pending.remove(id);
      if (p != null) {
        _restores[id] = restoreEpoch(id) + 1;
        _records.insert(p.index.clamp(0, _records.length), p.record);
        notifyListeners();
      }
    }
    return ok;
  }

  /// เลิกทำการลบ คืน false ถ้าบันทึกกลับลงเครื่องไม่สำเร็จ (รายการยังแสดงในรอบนี้แต่อาจหายเมื่อเปิดแอปใหม่)
  Future<bool> undoRemoval(String id) async {
    final p = _pending.remove(id);
    if (p == null) return true;
    _records.insert(p.index.clamp(0, _records.length), p.record);
    notifyListeners();
    return _persist();
  }

  /// ยืนยันการลบรายการที่รอเลิกทำ (ลบไฟล์รูปจริงเมื่อไม่มีข้อมูลถาวรอ้างถึง)
  /// เรียกซ้ำ/เรียกช้าหลัง undo หรือหลังล้างทั้งหมดได้โดยไม่มีผล
  Future<void> finalizeRemoval(String id) async {
    final p = _pending.remove(id);
    if (p == null) return;
    await _tail; // รอให้การเขียนที่ค้างอยู่เสร็จก่อน จึงรู้ว่าในเครื่องยังอ้างถึงรูปนี้หรือไม่
    _release([p.record.imageFile]);
    await _sweep();
  }

  /// ล้างทั้งหมด คืน true เมื่อทั้งประวัติและ draft ถูกลบออกจากเครื่องแล้ว
  /// ส่วนที่ลบไม่สำเร็จจะกลับมาแสดง พร้อมรูปที่ยังอยู่ครบ
  Future<bool> clear() async {
    final pending = _pending.values.toList();
    _pending.clear();
    final oldRecords = List<ScanRecord>.of(_records);
    final oldDraft = _draft;
    _records.clear();
    _draft = null;
    notifyListeners();
    final okHistory = await _persist();
    final okDraft = await _persistDraft();
    if (!okHistory) _records.addAll(oldRecords);
    if (!okDraft) _draft ??= oldDraft;
    if (!okHistory || !okDraft) notifyListeners();
    _release([
      for (final p in pending) p.record.imageFile,
      if (okHistory)
        for (final r in oldRecords) r.imageFile,
      if (okDraft) oldDraft?.imageFile,
    ]);
    await _sweep();
    if (okHistory && okDraft) await _images.deleteAll();
    return okHistory && okDraft;
  }

  /// ลบไฟล์รูปในโฟลเดอร์ของแอปที่ไม่มีรายการใดอ้างถึง (เช่น แอปถูกปิดระหว่างวิเคราะห์)
  /// ลบเฉพาะไฟล์ในโฟลเดอร์ scans ของแอปเท่านั้น
  Future<int> cleanupOrphans() async {
    // ร่างที่ถูกยืนยันไปแล้วแต่ยังค้างในเครื่อง → ลบ key ที่ค้าง
    if (_durableDraft?.id != _draft?.id) await _persistDraft();
    final keep = _referenced();
    final files = await _images.listFiles();
    var removed = 0;
    for (final f in files) {
      if (!keep.contains(f)) {
        await _images.delete(f);
        removed++;
      }
    }
    return removed;
  }
}
