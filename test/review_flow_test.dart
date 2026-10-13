import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/models/ingredient.dart';
import 'package:kinyangdeechao/models/scan_record.dart';
import 'package:kinyangdeechao/screens/ingredient_result_screen.dart';
import 'package:kinyangdeechao/screens/review/ingredient_review_screen.dart';

import 'test_helpers.dart';

ScanRecord _draft({List<DetectedIngredient>? items, int? reported}) {
  final list = items ??
      [egg.withSource(IngredientSource.ai), tomato.withSource(IngredientSource.ai)];
  return ScanRecord(
    id: 'd1',
    createdAt: DateTime.now(),
    imageFile: 'd1.jpg',
    status: ScanStatus.draft,
    detected: list,
    aiReportedCount: reported ?? list.length,
    ingredients: list,
    kitchen: const {'oil', 'salt'},
  );
}

Future<Harness> _openReview(WidgetTester tester, ScanRecord draft) async {
  usePhone(tester);
  final h = await Harness.create();
  await h.history.saveDraft(draft);
  await tester.pumpWidget(h.wrap(IngredientReviewScreen(recordId: draft.id)));
  await tester.pumpAndSettle();
  return h;
}

/// เลื่อนให้เห็นก่อนแตะ (จอ 360x640 มีรูปด้านบน รายการจึงอยู่ใต้ขอบจอ)
Future<void> _tap(WidgetTester tester, Finder f) => tapVisible(tester, f);

void main() {
  testWidgets('confirm moves the draft into history and opens results',
      (tester) async {
    final h = await _openReview(tester, _draft());
    expect(find.text('ไข่ไก่'), findsOneWidget);
    expect(find.text('AI ตรวจพบ'), findsNWidgets(2));

    await tester.tap(find.text('ยืนยันวัตถุดิบและหาเมนู (2)'));
    await tester.pumpAndSettle();

    expect(find.byType(IngredientResultScreen), findsOneWidget);
    expect(h.history.draft, isNull);
    final r = h.history.records.single;
    expect(r.status, ScanStatus.confirmed);
    expect(r.confirmedAt, isNotNull);
    expect(r.kitchen, {'oil', 'salt'});
    expect(r.changes.isEmpty, isTrue);
    expect(h.api.suggestCalls, 0, reason: 'ไม่เรียก AI เองเมื่อเปิดผลลัพธ์');
  });

  testWidgets('rename and remove are tracked as a change set', (tester) async {
    final h = await _openReview(tester, _draft());

    // แก้ "มะเขือเทศ" เป็น "พริก"
    await _tap(tester, find.byTooltip('แก้ชื่อ มะเขือเทศ'));
    await tester.enterText(find.byType(TextField), 'พริก');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.text('แก้จาก "มะเขือเทศ"'), findsOneWidget);

    // ลบไข่
    await _tap(tester, find.byTooltip('ลบ ไข่ไก่'));
    expect(find.text('ไข่ไก่'), findsNothing);
    // draft ถูกอัปเดตระหว่างตรวจ (กู้คืนได้ถ้าแอปถูกปิด)
    expect(h.history.draft!.ingredients.map((i) => i.id), ['chili']);

    await tester.tap(find.text('ยืนยันวัตถุดิบและหาเมนู (1)'));
    await tester.pumpAndSettle();
    final r = h.history.records.single;
    expect(r.detected.map((i) => i.nameTh), ['ไข่ไก่', 'มะเขือเทศ'],
        reason: 'ผล AI เดิมต้องไม่ถูกเขียนทับ');
    expect(r.ingredients.single.id, 'chili');
    expect(r.changes.renamed.single, const IngredientRename('มะเขือเทศ', 'พริก'));
    expect(r.changes.removed.single.nameTh, 'ไข่ไก่');
    expect(r.changes.added, isEmpty);
  });

  testWidgets('an unknown typed name is kept as typed (no fuzzy mapping)',
      (tester) async {
    final h = await _openReview(tester, _draft());
    await _tap(tester, find.byTooltip('แก้ชื่อ ไข่ไก่'));
    await tester.enterText(find.byType(TextField), 'ไข่เค็ม');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    final item = h.history.draft!.ingredients.first;
    expect(item.nameTh, 'ไข่เค็ม');
    expect(item.known, isFalse);
    expect(find.text('แก้จาก "ไข่ไก่" · ไม่อยู่ในฐานข้อมูล'), findsOneWidget);
  });

  testWidgets('kitchen staples are chosen by the user, not assumed',
      (tester) async {
    final h = await _openReview(tester, _draft());
    await _tap(tester, find.text('🫙 น้ำปลา'));
    await tester.tap(find.text('ยืนยันวัตถุดิบและหาเมนู (2)'));
    await tester.pumpAndSettle();
    expect(h.history.records.single.kitchen, {'oil', 'salt', 'fish_sauce'});
    expect(h.settings.kitchen, {'oil', 'salt', 'fish_sauce'},
        reason: 'จำเป็นค่าเริ่มต้นครั้งถัดไป');
  });

  testWidgets('over-limit AI results are announced, not hidden silently',
      (tester) async {
    await _openReview(tester, _draft(reported: 15));
    expect(find.textContaining('AI ตอบมา 15 รายการ'), findsOneWidget);
  });

  testWidgets('leaving asks: keep for later or discard (deletes image)',
      (tester) async {
    final h = await _openReview(tester, _draft());
    final nav = tester.state<NavigatorState>(find.byType(Navigator));

    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่ได้ยืนยันวัตถุดิบ'), findsOneWidget);
    await tester.tap(find.text('ตรวจต่อ'));
    await tester.pumpAndSettle();
    expect(find.byType(IngredientReviewScreen), findsOneWidget);

    await nav.maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทิ้งผลสแกน'));
    await tester.pumpAndSettle();
    expect(h.history.draft, isNull);
    expect(h.history.isEmpty, isTrue);
    expect(h.images.deleted, ['d1.jpg']);
  });

  testWidgets('legacy records must be reviewed before showing recipes',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    await h.history.add(ScanRecord(
      id: 'old',
      createdAt: DateTime.now(),
      status: ScanStatus.legacy,
      detected: const [egg],
      ingredients: const [egg],
    ));
    await tester.pumpWidget(h.wrap(const IngredientResultScreen(recordId: 'old')));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่ได้ยืนยันวัตถุดิบ'), findsOneWidget);
    expect(find.text('จากสูตรในแอป'), findsNothing);

    await tester.tap(find.text('ตรวจและยืนยันวัตถุดิบ'));
    await tester.pumpAndSettle();
    expect(find.text('รายการจากแอปเวอร์ชันก่อน'), findsOneWidget);
    await tester.tap(find.text('ยืนยันวัตถุดิบและหาเมนู (1)'));
    await tester.pumpAndSettle();
    expect(h.history.byId('old')!.status, ScanStatus.confirmed);
    expect(find.text('จากสูตรในแอป'), findsOneWidget);
  });
}
