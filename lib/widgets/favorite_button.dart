import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/recipe.dart';
import '../state/favorites_controller.dart' show FavoriteToggle;
import '../theme/palette.dart';
import '../theme/tokens.dart';

/// ข้อความแจ้งผลสลับเมนูโปรด — บอกว่า "บันทึกแล้ว" เฉพาะเมื่อเขียนลงเครื่องสำเร็จจริง
String favoriteToggleMessage(FavoriteToggle r) {
  if (r.saved) {
    return r.isFavorite ? 'บันทึกเป็นเมนูโปรดแล้ว' : 'เอาออกจากเมนูโปรดแล้ว';
  }
  return r.isFavorite
      ? 'ยังบันทึกเมนูโปรดลงเครื่องไม่สำเร็จ เมนูอาจหายเมื่อปิดแอป'
      : 'ยังบันทึกการเอาออกลงเครื่องไม่สำเร็จ เมนูอาจกลับมาเมื่อเปิดแอปใหม่';
}

/// ปุ่มหัวใจบันทึกเมนูโปรด (ขนาดสัมผัส 48dp, เด้งเบา ๆ และสั่นเมื่อกด)
class FavoriteButton extends StatelessWidget {
  final Recipe recipe;

  /// สีไอคอนตอนยังไม่ได้กด (บนภาพปกใช้สีขาว)
  final Color? idleColor;

  const FavoriteButton({super.key, required this.recipe, this.idleColor});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = context.palette;
    final isFav = scope.favorites.isFavorite(recipe);
    return IconButton(
      tooltip: isFav ? 'เอาออกจากเมนูโปรด' : 'บันทึกเป็นเมนูโปรด',
      isSelected: isFav,
      onPressed: () async {
        scope.settings.light();
        final messenger = ScaffoldMessenger.of(context);
        final r = await scope.favorites.toggle(recipe);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(favoriteToggleMessage(r)),
              duration: const Duration(seconds: 2),
            ),
          );
      },
      icon: AnimatedSwitcher(
        duration: Motion.normal,
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: Tween(
            begin: 0.6,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.elasticOut)),
          child: child,
        ),
        child: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(isFav),
          color: isFav ? p.accent : (idleColor ?? p.muted),
        ),
      ),
    );
  }
}
