import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../core/emoji_support.dart';

/// ภาพปกเมนูแบบสร้างด้วยโค้ด: ไล่สีตามหมวด + emoji วัตถุดิบหลัก + วงกลมตกแต่งแบบแบรนด์
/// ไม่ต้องใช้รูปจริง จึงมีภาพทุกเมนู (รวมสูตรจาก AI) และไม่ติดลิขสิทธิ์
class RecipeCover extends StatelessWidget {
  final Recipe recipe;
  final double? height;
  final double? width;
  final double radius;

  /// ขนาด emoji หลักเทียบกับด้านที่สั้นกว่าของภาพ
  final double emojiScale;

  /// ใส่ Hero (ใช้ตอนเปิดจากการ์ดไปหน้ารายละเอียด)
  final Object? heroTag;

  const RecipeCover({
    super.key,
    required this.recipe,
    this.height,
    this.width,
    this.radius = 16,
    this.emojiScale = 0.46,
    this.heroTag,
  });

  static const Map<RecipeCategory, List<Color>> _gradients = {
    RecipeCategory.main: [Color(0xFFFF9A6B), Color(0xFFE2412F)],
    RecipeCategory.soup: [Color(0xFFFFC067), Color(0xFFE8772E)],
    RecipeCategory.salad: [Color(0xFFB5D98A), Color(0xFF4E9A52)],
    RecipeCategory.noodle: [Color(0xFFFFDB7E), Color(0xFFE9A21E)],
    RecipeCategory.breakfast: [Color(0xFFFFE8B0), Color(0xFFF4B54E)],
    RecipeCategory.dessert: [Color(0xFFF9B9C6), Color(0xFFD9667F)],
  };

  static List<Color> colorsFor(RecipeCategory c) => _gradients[c]!;

  /// emoji รอง (วัตถุดิบอื่นที่ไม่ใช่เครื่องปรุง) สูงสุด 2 ตัว
  List<String> _sideEmojis() {
    final hero = recipe.heroEmoji;
    final out = <String>[];
    for (final i in recipe.ingredients) {
      final c = i.catalog;
      if (c == null || c.pantry || c.emoji == hero || out.contains(c.emoji)) {
        continue;
      }
      out.add(c.emoji);
      if (out.length == 2) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(recipe.category);
    final side = _sideEmojis();
    Widget cover = LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : (width ?? 120);
        final h = c.maxHeight.isFinite ? c.maxHeight : (height ?? 120);
        final s = w < h ? w : h;
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // วงกลมตกแต่ง (โทนขาวโปร่ง)
                Positioned(
                  right: -s * 0.25,
                  top: -s * 0.3,
                  child: _Blob(size: s * 0.9, alpha: 0.16),
                ),
                Positioned(
                  left: -s * 0.2,
                  bottom: -s * 0.35,
                  child: _Blob(size: s * 0.8, alpha: 0.12),
                ),
                Positioned(
                  left: w * 0.12,
                  top: h * 0.14,
                  child: _Blob(size: s * 0.09, alpha: 0.35),
                ),
                if (side.isNotEmpty && s > 70) ...[
                  Positioned(
                    left: w * 0.1,
                    bottom: h * 0.12,
                    child: _Emoji(side[0], s * 0.18, opacity: 0.9),
                  ),
                  if (side.length > 1)
                    Positioned(
                      right: w * 0.1,
                      top: h * 0.12,
                      child: _Emoji(side[1], s * 0.16, opacity: 0.85),
                    ),
                ],
                Center(
                  child: _Emoji(recipe.heroEmoji, s * emojiScale, shadow: true),
                ),
              ],
            ),
          ),
        );
      },
    );
    cover = SizedBox(width: width, height: height, child: cover);
    if (heroTag != null) cover = Hero(tag: heroTag!, child: cover);
    return ExcludeSemantics(child: cover);
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double alpha;

  const _Blob({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

class _Emoji extends StatelessWidget {
  final String emoji;
  final double size;
  final double opacity;
  final bool shadow;

  const _Emoji(this.emoji, this.size, {this.opacity = 1, this.shadow = false});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Text(
      safeEmoji(emoji),
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontSize: size,
        height: 1.1,
        shadows: shadow
            ? [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: size * 0.12,
                  offset: Offset(0, size * 0.05),
                ),
              ]
            : null,
      ),
    ),
  );
}
