import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../data/recipe_repository.dart';
import '../../theme/tokens.dart';
import '../../widgets/content_width.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/recipe_card.dart';
import '../recipe_detail_screen.dart';
import '../search/search_screen.dart';

/// แท็บ "เมนูโปรด": เมนูที่บันทึกไว้ (รวมสูตรที่ AI สร้าง) ดูได้แม้ออฟไลน์
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = AppScope.of(context).favorites.recipes;
    return Scaffold(
      appBar: AppBar(
        title: const Text('เมนูโปรด'),
        actions: [
          IconButton(
            tooltip: 'ค้นหาสูตรอาหาร',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: favorites.isEmpty
              ? EmptyState(
                  icon: Icons.favorite_border,
                  title: 'ยังไม่มีเมนูโปรด',
                  message:
                      'แตะรูปหัวใจที่เมนูเพื่อบันทึกไว้\nแล้วกลับมาดูได้ทุกเมื่อ แม้ไม่มีเน็ต',
                  actionLabel: 'ดูสูตรทั้งหมด',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Space.screen,
                    Space.xs,
                    Space.screen,
                    Space.xl,
                  ),
                  itemCount: favorites.length,
                  itemBuilder: (context, i) {
                    final match = RecipeMatch.browse(favorites[i]);
                    return RecipeCard(
                      key: ValueKey(favorites[i].favoriteKey),
                      match: match,
                      heroScope: 'fav',
                      onTap: () => Navigator.of(
                        context,
                      ).push(RecipeDetailScreen.route(match, heroScope: 'fav')),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
