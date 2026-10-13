import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/core/emoji_support.dart';
import 'package:kinyangdeechao/data/catalog/ingredients_catalog.dart';

/// emoji ที่มาหลัง Emoji 11 (ฟอนต์ของ Android 9 ไม่มี → เป็นกล่องว่าง)
const _newerThanAndroid9 = {
  '🧄', '🧅', '🧈', '🧊', '🫑', '🫙', '🫗', '🫚', '🫛', //
  '🧇', '🧆', '🦪', '🧃', '🧉', '🫒', '🫓', '🫔', '🫕', '🫖', '🫐', '🫘',
};

void main() {
  tearDown(() => EmojiSupport.sdkForTesting = null);

  test('Android 9 (API 28) gets a fallback for every catalog emoji it cannot draw', () {
    EmojiSupport.sdkForTesting = 28;
    for (final i in IngredientCatalog.all) {
      expect(_newerThanAndroid9.contains(safeEmoji(i.emoji)), isFalse,
          reason: '${i.id} ${i.emoji} → ${safeEmoji(i.emoji)}');
    }
    expect(safeEmoji('🥚'), '🥚');
  });

  test('newer Android keeps the original emoji', () {
    EmojiSupport.sdkForTesting = 34;
    expect(safeEmoji('🧄'), '🧄');
    expect(safeEmoji('🫚'), '🫚');
    EmojiSupport.sdkForTesting = 30;
    expect(safeEmoji('🫑'), '🫑');
    expect(safeEmoji('🫙'), isNot('🫙'), reason: 'Emoji 14 ต้อง API 33');
  });

  test('unknown platform (tests, iOS) keeps the original', () {
    expect(safeEmoji('🧅'), '🧅');
  });
}
