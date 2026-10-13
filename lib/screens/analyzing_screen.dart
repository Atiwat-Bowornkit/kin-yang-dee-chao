import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../core/app_scope.dart';
import '../models/scan_record.dart';
import '../services/api_service.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/brand_loading.dart';
import 'review/ingredient_review_screen.dart';

/// หน้า loading เต็มจอระหว่างวิเคราะห์ภาพ
/// สำเร็จ (รวมกรณีไม่พบวัตถุดิบ) → เก็บรูป + ผลเป็น "ยังไม่ยืนยัน" แล้วไปหน้าตรวจวัตถุดิบ
/// ล้มเหลว → ปิดหน้านี้และส่งข้อความ error (String) กลับไปให้หน้าเดิมแสดง
/// ยกเลิก → หยุดคำขอที่ค้างอยู่จริง (CancelToken) ไม่บันทึกอะไร และลบรูปที่คัดลอกไว้
class AnalyzingScreen extends StatefulWidget {
  final XFile image;
  final VoidCallback? onSuccess;

  const AnalyzingScreen({super.key, required this.image, this.onSuccess});

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  final _cancelToken = CancelToken();
  final _watch = Stopwatch()..start();
  Timer? _ticker;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    // แสดงเวลาที่ผ่านไปจริง (ไม่เดาเปอร์เซ็นต์หรือเวลาที่จะเสร็จ)
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _run();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (!_cancelToken.isCancelled) _cancelToken.cancel();
    super.dispose();
  }

  bool get _stopped => _cancelled || !mounted;

  Future<void> _run() async {
    final scope = AppScope.read(context);
    final RecognitionOutcome outcome;
    try {
      outcome = await scope.api.recognizeIngredient(
        widget.image,
        cancelToken: _cancelToken,
      );
    } on RecognitionException catch (e) {
      if (e.type != RecognitionErrorType.cancelled) _fail(e.userMessage);
      return;
    } catch (e) {
      if (kDebugMode) debugPrint('unexpected: ${e.runtimeType}');
      _fail('ไม่สามารถวิเคราะห์ภาพได้ในขณะนี้\nกรุณาลองใหม่');
      return;
    }
    if (_stopped) return;

    // เก็บรูปไว้ในโฟลเดอร์ของแอป (ใช้แสดงในหน้าตรวจ/ประวัติ) — ถ้าเก็บไม่ได้ยังตรวจต่อได้
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final file = await scope.images.save(widget.image, id);
    if (_stopped) {
      await scope.images.delete(file);
      return;
    }

    final result = outcome.result;
    final draft = ScanRecord(
      id: id,
      createdAt: DateTime.now(),
      imageFile: file,
      status: ScanStatus.draft,
      detected: result.ingredients,
      aiReportedCount: result.reportedCount,
      ingredients: result.ingredients,
      kitchen: scope.settings.kitchen,
      conditions: scope.settings.conditions,
      traces: [outcome.trace],
    );
    final saved = await scope.history.saveDraft(draft);
    if (_stopped) {
      // ผู้ใช้ยกเลิกระหว่างบันทึก → ทิ้ง draft นี้ทั้งหมด
      if (scope.history.draft?.id == id) await scope.history.discardDraft();
      return;
    }
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'ยังบันทึกผลสแกนลงเครื่องไม่สำเร็จ ตรวจต่อได้ แต่ถ้าปิดแอปจะกู้คืนไม่ได้',
            ),
          ),
        );
    }

    scope.settings.medium();
    widget.onSuccess?.call();
    _ticker?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: Motion.slow,
        pageBuilder: (_, _, _) => IngredientReviewScreen(recordId: id),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _fail(String message) {
    if (_stopped) return;
    Navigator.of(context).pop(message);
  }

  void _cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancelToken.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _watch.elapsed.inSeconds;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 5),
              const BrandLoading(
                message: 'กำลังวิเคราะห์วัตถุดิบ...',
                hint:
                    'AI กำลังดูว่าในภาพมีอะไรบ้าง\nเสร็จแล้วคุณจะได้ตรวจรายการก่อนหาเมนู',
              ),
              const SizedBox(height: Space.md),
              Text('ผ่านไป $seconds วินาที', style: context.text.bodySmall),
              const Spacer(flex: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xl),
                child: TextButton(
                  onPressed: _cancel,
                  child: const Text('ยกเลิก'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
