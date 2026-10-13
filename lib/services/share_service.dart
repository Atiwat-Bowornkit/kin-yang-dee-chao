import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_constants.dart';
import '../models/recipe.dart';
import '../widgets/info_pill.dart';

/// ข้อความสูตรสำหรับแชร์ (ปรับปริมาณตามจำนวนที่)
String recipeShareText(Recipe recipe, {int? servings}) {
  final s = servings ?? recipe.servings;
  final factor = s / recipe.servings;
  final buf = StringBuffer()
    ..writeln('🍽️ ${recipe.nameTh}')
    ..writeln(
      '⏱ ${recipeTimeLabel(recipe)} · ${recipe.difficulty.label} · $s ที่',
    );
  if (recipe.description.isNotEmpty) buf.writeln(recipe.description);
  buf
    ..writeln()
    ..writeln('🧺 ส่วนผสม');
  for (final i in recipe.ingredients) {
    final opt = i.optional ? ' (ถ้ามี)' : '';
    buf.writeln('• ${i.name} — ${i.amountLabel(factor)}$opt');
  }
  buf
    ..writeln()
    ..writeln('👩‍🍳 วิธีทำ');
  for (var i = 0; i < recipe.steps.length; i++) {
    buf.writeln('${i + 1}. ${recipe.steps[i]}');
  }
  if (recipe.isAiGenerated) {
    buf
      ..writeln()
      ..writeln('* สูตรนี้สร้างโดย AI ควรตรวจสอบก่อนปรุงจริง');
  }
  buf
    ..writeln()
    ..write('— ${recipe.sourceLabel} · แชร์จากแอป ${AppConstants.appName}');
  return buf.toString();
}

class ShareService {
  const ShareService();

  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  /// เรนเดอร์ [boundary] เป็น PNG แล้วแชร์ผ่านเมนูแชร์ของระบบ
  Future<void> shareBoundaryImage(
    RenderRepaintBoundary boundary, {
    required String fileName,
    String? text,
  }) async {
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('สร้างรูปไม่สำเร็จ');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName.png');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    if (kDebugMode) debugPrint('share image: ${file.path}');
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
      ),
    );
  }
}
