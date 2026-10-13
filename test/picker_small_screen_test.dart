import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/data/catalog/ingredients_catalog.dart';
import 'package:kinyangdeechao/models/ingredient.dart';
import 'package:kinyangdeechao/screens/ingredient_picker_sheet.dart';

import 'test_helpers.dart';

/// IngredientPicker เป็น bottom sheet จริง บนจอ 360×640 ตัวอักษร 1.3× เลือกใกล้ 12 รายการ
/// แล้วเปิดคีย์บอร์ด (viewInsets) — ต้องไม่ overflow และปุ่มยืนยัน/ช่องค้นหาต้องกดได้
const _keyboard = 280.0; // ความสูงคีย์บอร์ดมือถือทั่วไป (dp) ที่จอ 640dp

List<DetectedIngredient> _items(int n) => [
  for (final i in IngredientCatalog.selectable.take(n))
    DetectedIngredient.fromCatalog(i),
];

Future<void> _openPicker(
  WidgetTester tester,
  Harness h, {
  required int initial,
  required void Function(List<DetectedIngredient>?) onResult,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(
    h.wrap(
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async => onResult(
              await showIngredientPicker(
                context,
                initial: _items(initial),
                confirmLabel: 'ยืนยันและหาเมนู',
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('12 selected + keyboard open at 360×640, 1.3× text: no overflow, '
      'confirm and search stay usable', (tester) async {
    final h = await Harness.create();
    List<DetectedIngredient>? result;
    var closed = false;
    await _openPicker(
      tester,
      h,
      initial: 11,
      onResult: (r) {
        result = r;
        closed = true;
      },
    );
    // ตัวอักษรขยายจริง
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(IngredientPicker)),
      ).scale(10),
      13,
    );

    // เลือกรายการที่ 12 จากรายการด้านล่าง
    final next = IngredientCatalog.selectable[11];
    final chip = find.text(next.nameTh); // ชิปที่ยังไม่ได้เลือกมีเพียงตัวเดียว
    await tester.scrollUntilVisible(
      chip,
      100,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('12/12'), findsOneWidget);

    // เปิดคีย์บอร์ด: โฟกัสช่องค้นหา + viewInsets
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'ห้ามมี overflow/exception');

    final keyboardTop = 640 - _keyboard;
    final field = tester.getRect(find.byType(TextField));
    final confirm = find.widgetWithText(FilledButton, 'ยืนยันและหาเมนู (12)');
    final button = tester.getRect(confirm);
    // ช่องค้นหาและปุ่มยืนยันต้องอยู่เหนือคีย์บอร์ด (กดได้)
    expect(
      field.bottom,
      lessThanOrEqualTo(keyboardTop),
      reason: 'ช่องค้นหาถูกคีย์บอร์ดบัง',
    );
    expect(
      button.bottom,
      lessThanOrEqualTo(keyboardTop),
      reason: 'ปุ่มยืนยันถูกคีย์บอร์ดบัง',
    );
    expect(button.top, greaterThanOrEqualTo(0));

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, hasLength(12));
  });

  testWidgets('typing with the keyboard open still leaves room for results', (
    tester,
  ) async {
    final h = await Harness.create();
    await _openPicker(tester, h, initial: 12, onResult: (_) {});
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'หมู');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // พื้นที่ของรายการผลค้นหาที่เหลือเหนือคีย์บอร์ดต้องพอแสดงอย่างน้อยหนึ่งชิป
    final list = tester.getRect(find.byType(ListView).last);
    final visibleBottom = 640 - _keyboard;
    final visibleHeight = visibleBottom - list.top;
    expect(
      visibleHeight,
      greaterThan(48),
      reason: 'พื้นที่รายการเหลือ ${visibleHeight.toStringAsFixed(0)}dp',
    );
  });
}
