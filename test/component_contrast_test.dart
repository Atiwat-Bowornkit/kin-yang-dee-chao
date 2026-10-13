import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/theme/app_theme.dart';
import 'package:kinyangdeechao/widgets/ai_badge.dart';

import 'palette_test.dart' show contrast;

/// ตรวจ contrast จากสีที่ widget จริงใช้หลังเรนเดอร์ (ไม่ใช่แค่ค่าใน palette)
/// ข้อความปกติ AA = 4.5:1, ปุ่มที่ปิดใช้งานไม่บังคับตาม WCAG แต่ตั้งไว้ ≥ 3:1 ให้ยังอ่านได้
const _aa = 4.5;
const _disabledMin = 3.0;

Color _textColor(WidgetTester tester, Finder text) {
  final p = tester.renderObject<RenderParagraph>(text);
  return p.text.style!.color!;
}

Color _materialBehind(WidgetTester tester, Finder text, Color page) {
  final materials = tester
      .widgetList<Material>(find.ancestor(of: text, matching: find.byType(Material)))
      .where((m) => m.type != MaterialType.transparency && m.color != null);
  final c = materials.isEmpty ? page : materials.first.color!;
  return Color.alphaBlend(c, page);
}

void main() {
  for (final dark in [false, true]) {
    final name = dark ? 'dark' : 'light';
    final theme = dark ? darkAppTheme : lightAppTheme;
    final page = theme.scaffoldBackgroundColor;
    final results = <String, double>{};

    Future<void> pump(WidgetTester tester, Widget body) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(body: Center(child: body)),
      ));
      await tester.pumpAndSettle();
    }

    void check(String what, Color fg, Color bg, double min) {
      final r = contrast(fg, bg);
      results[what] = r;
      expect(r, greaterThanOrEqualTo(min),
          reason: '$name/$what ${r.toStringAsFixed(2)}:1');
    }

    group('$name theme components', () {
      testWidgets('snackbar text and action', (tester) async {
        await pump(tester, Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('ลบแล้ว'),
                action: SnackBarAction(label: 'เลิกทำ', onPressed: () {}),
              ),
            ),
            child: const Text('show'),
          ),
        ));
        await tester.tap(find.text('show'));
        await tester.pumpAndSettle();
        final bg = _materialBehind(tester, find.text('ลบแล้ว'), page);
        check('snackbar text', _textColor(tester, find.text('ลบแล้ว')), bg, _aa);
        check('snackbar action', _textColor(tester, find.text('เลิกทำ')), bg, _aa);
      });

      testWidgets('filter chips selected / unselected', (tester) async {
        await pump(
          tester,
          Wrap(children: [
            FilterChip(label: const Text('เลือกแล้ว'), selected: true, onSelected: (_) {}),
            FilterChip(label: const Text('ยังไม่เลือก'), selected: false, onSelected: (_) {}),
            ChoiceChip(label: const Text('ตัวเลือก'), selected: true, onSelected: (_) {}),
          ]),
        );
        final chip = theme.chipTheme;
        check('chip selected', _textColor(tester, find.text('เลือกแล้ว')),
            Color.alphaBlend(chip.selectedColor!, page), _aa);
        check('chip unselected', _textColor(tester, find.text('ยังไม่เลือก')),
            Color.alphaBlend(chip.backgroundColor!, page), _aa);
        check('choice chip selected', _textColor(tester, find.text('ตัวเลือก')),
            Color.alphaBlend(chip.selectedColor!, page), _aa);
      });

      testWidgets('AI badge', (tester) async {
        await pump(tester, const AiBadge());
        final box = tester.widget<Container>(find.descendant(
            of: find.byType(AiBadge), matching: find.byType(Container)));
        final bg = (box.decoration! as BoxDecoration).color!;
        check('ai badge', _textColor(tester, find.text('สูตรจาก AI')),
            Color.alphaBlend(bg, page), _aa);
      });

      testWidgets('count badge on the navigation bar', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            bottomNavigationBar: NavigationBar(destinations: const [
              NavigationDestination(icon: Icon(Icons.qr_code), label: 'สแกน'),
              NavigationDestination(
                  icon: Badge(label: Text('3'), child: Icon(Icons.shopping_basket)),
                  label: 'ซื้อของ'),
            ]),
          ),
        ));
        await tester.pumpAndSettle();
        final badgeBg = theme.badgeTheme.backgroundColor ?? theme.colorScheme.error;
        check('count badge', _textColor(tester, find.text('3')), badgeBg, _aa);
        final navBg = Color.alphaBlend(
            theme.navigationBarTheme.backgroundColor ?? theme.colorScheme.surface, page);
        check('nav label unselected', _textColor(tester, find.text('ซื้อของ')), navBg, _aa);
        check('nav label selected', _textColor(tester, find.text('สแกน')), navBg, _aa);
      });

      testWidgets('filled button enabled / disabled', (tester) async {
        await pump(
          tester,
          Column(mainAxisSize: MainAxisSize.min, children: [
            FilledButton(onPressed: () {}, child: const Text('ยืนยัน')),
            const FilledButton(onPressed: null, child: Text('ปิดอยู่')),
          ]),
        );
        check('button enabled', _textColor(tester, find.text('ยืนยัน')),
            _materialBehind(tester, find.text('ยืนยัน'), page), _aa);
        check('button disabled', _textColor(tester, find.text('ปิดอยู่')),
            _materialBehind(tester, find.text('ปิดอยู่'), page), _disabledMin);
      });

      tearDownAll(() {
        // แสดงค่าจริงไว้ใช้รายงาน
        // ignore: avoid_print
        print('contrast $name: ${results.map((k, v) => MapEntry(k, v.toStringAsFixed(2)))}');
      });
    });
  }
}
