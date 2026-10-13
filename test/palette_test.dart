import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/theme/palette.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // WCAG AA สำหรับข้อความปกติ = 4.5:1
  const aa = 4.5;

  for (final entry in {
    'light': AppPalette.light,
    'dark': AppPalette.dark,
  }.entries) {
    final p = entry.value;
    group('${entry.key} palette contrast (AA)', () {
      test('body text on background and surface', () {
        expect(contrast(p.ink, p.background), greaterThanOrEqualTo(aa));
        expect(contrast(p.ink, p.surface), greaterThanOrEqualTo(aa));
      });
      test('muted text on background and surface', () {
        expect(contrast(p.muted, p.background), greaterThanOrEqualTo(aa));
        expect(contrast(p.muted, p.surface), greaterThanOrEqualTo(aa));
      });
      test('accent text on background and surface', () {
        expect(contrast(p.accent, p.background), greaterThanOrEqualTo(aa));
        expect(contrast(p.accent, p.surface), greaterThanOrEqualTo(aa));
      });
      test('label on filled accent button', () {
        expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(aa));
      });
      test('success text on background and surface', () {
        expect(contrast(p.success, p.background), greaterThanOrEqualTo(aa));
        expect(contrast(p.success, p.surface), greaterThanOrEqualTo(aa));
      });
      test('ink text on soft gold panels and surfaceAlt', () {
        expect(contrast(p.ink, Color.alphaBlend(p.goldSoft, p.background)),
            greaterThanOrEqualTo(aa));
        expect(contrast(p.muted, p.surfaceAlt), greaterThanOrEqualTo(aa));
      });
      test('error text on background and surface', () {
        expect(contrast(p.error, p.background), greaterThanOrEqualTo(aa));
        expect(contrast(p.error, p.surface), greaterThanOrEqualTo(aa));
      });
    });
  }
}
