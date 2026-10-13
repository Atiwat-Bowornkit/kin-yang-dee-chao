import 'package:flutter/material.dart';

import '../../data/recipe_repository.dart';
import '../../models/recipe.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/content_width.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/recipe_card.dart';
import '../recipe_detail_screen.dart';

/// "สูตรอาหาร": ดูสูตรทั้งหมดในแอป ค้นหาจากชื่อเมนู/ส่วนผสม และกรองได้ (ทำงานออฟไลน์)
class SearchScreen extends StatefulWidget {
  /// เปิดช่องค้นหาพร้อมคีย์บอร์ดทันที
  final bool autofocus;

  const SearchScreen({super.key, this.autofocus = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  static const _repo = RecipeRepository();

  RecipeFilter _filter = RecipeFilter.none;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final query = _controller.text.trim();
    final results = query.isEmpty
        ? [for (final r in _repo.browse(_filter)) RecipeMatch.browse(r)]
        : _repo.search(query, filter: _filter);

    return Scaffold(
      appBar: AppBar(title: const Text('สูตรอาหาร')),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.screen,
                  0,
                  Space.screen,
                  Space.sm,
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: widget.autofocus,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'ค้นหาเมนูหรือวัตถุดิบ เช่น ไข่, ต้มยำ',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'ล้างคำค้นหา',
                            icon: const Icon(Icons.close),
                            onPressed: _clear,
                          ),
                  ),
                ),
              ),
              _FilterBar(
                filter: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.screen,
                  Space.sm,
                  Space.screen,
                  Space.xs,
                ),
                child: Row(
                  children: [
                    Text(
                      query.isEmpty && _filter.isEmpty
                          ? 'ทั้งหมด ${results.length} เมนู'
                          : 'พบ ${results.length} เมนู',
                      style: context.text.bodySmall,
                    ),
                    const Spacer(),
                    if (!_filter.isEmpty)
                      TextButton(
                        onPressed: () =>
                            setState(() => _filter = RecipeFilter.none),
                        child: const Text('ล้างตัวกรอง'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        title: 'ไม่พบเมนู',
                        message: query.isEmpty
                            ? 'ไม่มีเมนูที่ตรงกับตัวกรอง\nลองเอาตัวกรองบางอย่างออก'
                            : 'ไม่พบเมนูที่ตรงกับ "$query"\nลองใช้ชื่อวัตถุดิบ เช่น หมู ไข่ ผักบุ้ง',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          Space.screen,
                          Space.xs,
                          Space.screen,
                          Space.xl,
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: results.length,
                        itemBuilder: (context, i) => RecipeCard(
                          key: ValueKey(results[i].recipe.id),
                          match: results[i],
                          heroScope: 'search',
                          onTap: () => Navigator.of(context).push(
                            RecipeDetailScreen.route(
                              results[i],
                              heroScope: 'search',
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: p.background,
    );
  }
}

/// แถบตัวกรองแบบเลื่อนแนวนอน: หมวด + เวลา + มังสวิรัติ/ไม่เผ็ด/ไม่ใช้เตา
class _FilterBar extends StatelessWidget {
  final RecipeFilter filter;
  final ValueChanged<RecipeFilter> onChanged;

  const _FilterBar({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: Space.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
        children: [
          chip(
            '≤ 15 นาที',
            filter.maxMinutes == 15,
            () => onChanged(
              filter.copyWith(maxMinutes: filter.maxMinutes == 15 ? null : 15),
            ),
          ),
          chip(
            '≤ 30 นาที',
            filter.maxMinutes == 30,
            () => onChanged(
              filter.copyWith(maxMinutes: filter.maxMinutes == 30 ? null : 30),
            ),
          ),
          chip(
            'ทำง่าย',
            filter.difficulty == Difficulty.easy,
            () => onChanged(
              filter.copyWith(
                difficulty: filter.difficulty == Difficulty.easy
                    ? null
                    : Difficulty.easy,
              ),
            ),
          ),
          chip(
            'มังสวิรัติ',
            filter.vegetarian,
            () => onChanged(filter.copyWith(vegetarian: !filter.vegetarian)),
          ),
          chip(
            'ไม่เผ็ด',
            filter.notSpicy,
            () => onChanged(filter.copyWith(notSpicy: !filter.notSpicy)),
          ),
          chip(
            'ไม่ใช้เตา',
            filter.noStove,
            () => onChanged(filter.copyWith(noStove: !filter.noStove)),
          ),
          for (final c in RecipeCategory.values)
            chip(
              '${c.emoji} ${c.label}',
              filter.category == c,
              () => onChanged(
                filter.copyWith(category: filter.category == c ? null : c),
              ),
            ),
        ],
      ),
    );
  }
}
