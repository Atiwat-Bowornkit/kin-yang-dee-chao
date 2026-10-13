import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:kinyangdeechao/constants/app_constants.dart';
import 'package:kinyangdeechao/models/ingredient.dart';
import 'package:kinyangdeechao/models/ingredient_recognition_result.dart';
import 'package:kinyangdeechao/models/scan_record.dart';
import 'package:kinyangdeechao/screens/analyzing_screen.dart';
import 'package:kinyangdeechao/screens/review/ingredient_review_screen.dart';
import 'package:kinyangdeechao/services/api_service.dart';

import 'test_helpers.dart';

/// หน้าแม่ที่ push AnalyzingScreen แล้วเก็บค่า (ข้อความ error) ที่ส่งกลับมา
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? returned = 'none';
  int successes = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('returned: $returned'),
          Text('success: $successes'),
          TextButton(
            onPressed: () async {
              final r = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => AnalyzingScreen(
                    image: XFile('fake.jpg'),
                    onSuccess: () => setState(() => successes++),
                  ),
                ),
              );
              setState(() => returned = r);
            },
            child: const Text('go'),
          ),
        ],
      ),
    );
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets(
      'result goes to the review step as an unconfirmed draft (not history)',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    await tester.pumpWidget(h.wrap(const _Host()));
    await _open(tester);

    expect(
      find.byWidgetPredicate(
        (w) => w is Image && w.semanticLabel == AppConstants.appName,
      ),
      findsOneWidget,
    );
    expect(find.text('กำลังวิเคราะห์วัตถุดิบ...'), findsOneWidget);
    // แสดงเวลาที่ผ่านไปจริง ไม่ใช่เปอร์เซ็นต์ที่เดา
    expect(find.textContaining('ผ่านไป'), findsOneWidget);

    h.api.recognize.complete(IngredientRecognitionResult.fromAiJson({
      'ingredients': ['egg', 'tomato'],
    }));
    await tester.pumpAndSettle();

    expect(find.byType(IngredientReviewScreen), findsOneWidget);
    expect(find.text('AI ตรวจพบ 2 รายการ — ตรวจให้ถูกก่อนหาเมนู'), findsOneWidget);
    expect(h.history.isEmpty, isTrue, reason: 'ยังไม่ยืนยัน ต้องไม่อยู่ในประวัติ');
    final draft = h.history.draft!;
    expect(draft.status, ScanStatus.draft);
    expect(draft.detected.map((i) => i.id), ['egg', 'tomato']);
    expect(draft.detected.first.source, IngredientSource.ai);
    expect(draft.imageFile, endsWith('.jpg'));
    expect(draft.traces.single.parserStatus, 'ok');
    expect(h.api.suggestCalls, 0, reason: 'ผลที่ยังไม่ยืนยันห้ามส่งไปขอสูตร');
    expect(find.text('success: 1'), findsNothing); // หน้าแม่ถูกบังอยู่
  });

  testWidgets('an empty result still opens review with guidance',
      (tester) async {
    usePhone(tester);
    final h = await Harness.create();
    await tester.pumpWidget(h.wrap(const _Host()));
    await _open(tester);

    h.api.recognize.complete(IngredientRecognitionResult(const []));
    await tester.pumpAndSettle();

    expect(find.text('AI ไม่พบวัตถุดิบในภาพนี้'), findsOneWidget);
    await seeVisible(tester, find.text('เลือกวัตถุดิบเอง'));
    expect(find.text('เพิ่มวัตถุดิบอย่างน้อย 1 อย่าง'), findsOneWidget);
    final cta = tester.widget<FilledButton>(find.ancestor(
        of: find.text('เพิ่มวัตถุดิบอย่างน้อย 1 อย่าง'),
        matching: find.byWidgetPredicate((w) => w is FilledButton)));
    expect(cta.onPressed, isNull);
    expect(h.history.isEmpty, isTrue);
  });

  testWidgets('error closes the loading page and returns the message',
      (tester) async {
    final h = await Harness.create();
    await tester.pumpWidget(h.wrap(const _Host()));
    await _open(tester);

    h.api.recognize.completeError(
      const RecognitionException(RecognitionErrorType.timeout),
    );
    await tester.pumpAndSettle();

    expect(find.text('กำลังวิเคราะห์วัตถุดิบ...'), findsNothing);
    expect(
      find.text(
        'returned: ${const RecognitionException(RecognitionErrorType.timeout).userMessage}',
      ),
      findsOneWidget,
    );
    expect(h.history.isEmpty, isTrue);
    expect(h.history.draft, isNull);
    expect(h.images.saved, isEmpty);
  });

  testWidgets('cancel aborts the request and ignores late results',
      (tester) async {
    final h = await Harness.create();
    await tester.pumpWidget(h.wrap(const _Host()));
    await _open(tester);

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(find.text('returned: null'), findsOneWidget);
    expect(h.api.lastRecognizeToken?.isCancelled, isTrue);

    h.api.recognize.complete(IngredientRecognitionResult.fromAiJson({
      'ingredients': ['egg'],
    }));
    await tester.pumpAndSettle();
    expect(find.byType(IngredientReviewScreen), findsNothing);
    expect(find.text('success: 0'), findsOneWidget);
    expect(h.history.isEmpty, isTrue);
    expect(h.history.draft, isNull);
    expect(h.images.saved, isEmpty, reason: 'ไม่คัดลอกรูปหลังยกเลิก');
  });

  testWidgets('system back during analysis cancels like the cancel button',
      (tester) async {
    final h = await Harness.create();
    await tester.pumpWidget(h.wrap(const _Host()));
    await _open(tester);

    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('returned: null'), findsOneWidget);
    expect(h.api.lastRecognizeToken?.isCancelled, isTrue);
  });
}
