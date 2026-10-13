import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';

import '../models/scan_record.dart' show fileNameOf;

/// เก็บรูปที่สแกนไว้ในโฟลเดอร์ของแอป (ไม่ใช่ cache ที่ระบบลบได้)
/// ภายนอกอ้างอิงรูปด้วย "ชื่อไฟล์" เท่านั้น แล้วแปลงเป็น path ด้วย [pathFor]
class ImageStore {
  ImageStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;
  String? _scansPath;

  /// เรียกครั้งเดียวตอนเปิดแอป เพื่อให้ [pathFor] ทำงานแบบ sync ได้
  Future<void> init() async {
    if (kIsWeb) return;
    try {
      _scansPath = (await _scansDir()).path;
    } catch (e) {
      if (kDebugMode) debugPrint('ImageStore.init failed: $e');
    }
  }

  Future<Directory> _scansDir() async {
    final base = await _baseDir();
    final dir = Directory('${base.path}${Platform.pathSeparator}scans');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// path เต็มของรูปจากชื่อไฟล์ (null ถ้าไม่มีรูป/ยังไม่ init)
  String? pathFor(String? fileName) {
    if (fileName == null || _scansPath == null) return null;
    return '$_scansPath${Platform.pathSeparator}$fileName';
  }

  static String _extensionOf(XFile image) {
    final mime = image.mimeType?.toLowerCase();
    if (mime == 'image/png') return 'png';
    if (mime == 'image/webp') return 'webp';
    final name = image.name.toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot >= 0) {
      final ext = name.substring(dot + 1);
      if (const ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext)) {
        return ext == 'jpeg' ? 'jpg' : ext;
      }
    }
    return 'jpg';
  }

  /// คัดลอกรูปเข้าที่เก็บของแอป คืน "ชื่อไฟล์" หรือ null ถ้าทำไม่ได้
  Future<String?> save(XFile image, String id) async {
    if (kIsWeb) return null;
    try {
      final dir = await _scansDir();
      _scansPath ??= dir.path;
      final name = '$id.${_extensionOf(image)}';
      await File(image.path).copy('${dir.path}${Platform.pathSeparator}$name');
      return name;
    } catch (e) {
      if (kDebugMode) debugPrint('ImageStore.save failed: $e');
      return null;
    }
  }

  /// ลบไฟล์ในโฟลเดอร์ของแอป (รับเฉพาะชื่อไฟล์ ไม่รับ path เพื่อไม่ให้ลบไฟล์นอกโฟลเดอร์)
  Future<void> delete(String? fileName) async {
    if (kIsWeb || fileName == null) return;
    if (fileName.isEmpty ||
        fileName.contains('/') ||
        fileName.contains(r'\') ||
        fileName.contains('..')) {
      return;
    }
    try {
      final dir = await _scansDir();
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      if (await file.exists()) await file.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('ImageStore.delete failed: $e');
    }
  }

  /// ชื่อไฟล์ทั้งหมดในโฟลเดอร์ scans ของแอป (ใช้หาไฟล์ที่ไม่มีรายการอ้างถึง)
  Future<List<String>> listFiles() async {
    if (kIsWeb) return const [];
    try {
      final dir = await _scansDir();
      final out = <String>[];
      await for (final e in dir.list(followLinks: false)) {
        final name = e is File ? fileNameOf(e.path) : null;
        if (name != null) out.add(name);
      }
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('ImageStore.listFiles failed: $e');
      return const [];
    }
  }

  /// ไฟล์รูปยังอยู่หรือไม่ (ไม่เรียกใน build)
  Future<bool> exists(String? fileName) async {
    final path = pathFor(fileName);
    if (path == null) return false;
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteAll() async {
    if (kIsWeb) return;
    try {
      final dir = await _scansDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      if (kDebugMode) debugPrint('ImageStore.deleteAll failed: $e');
    }
  }
}
