import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'brand_logo.dart';
import 'info_pill.dart';
import 'recipe_cover.dart';

/// การ์ดสูตรสำหรับแชร์เป็นรูปภาพ (กว้าง 360 คงที่ ใช้ธีมสว่างเสมอเพื่อให้รูปที่แชร์เหมือนกันทุกครั้ง)
class RecipeShareCard extends StatelessWidget {
  final Recipe recipe;
  final int servings;

  const RecipeShareCard({
    super.key,
    required this.recipe,
    required this.servings,
  });

  static const width = 360.0;
  static const _maxIngredients = 10;
  static const _maxSteps = 6;

  @override
  Widget build(BuildContext context) {
    final factor = servings / recipe.servings;
    return Theme(
      data: lightAppTheme,
      child: Builder(
        builder: (context) {
          final p = context.palette;
          final t = context.text;
          final ingredients = recipe.ingredients.take(_maxIngredients).toList();
          final steps = recipe.steps.take(_maxSteps).toList();
          return MediaQuery.withNoTextScaling(
            child: Container(
              width: width,
              color: p.background,
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RecipeCover(
                    recipe: recipe,
                    height: 170,
                    width: width - Space.lg * 2,
                    radius: Radii.lg,
                  ),
                  const SizedBox(height: Space.md),
                  Text(recipe.nameTh, style: t.headlineSmall),
                  if (recipe.description.isNotEmpty)
                    Text(recipe.description, style: t.bodySmall),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      InfoPill(
                        icon: Icons.schedule,
                        label: recipeTimeLabel(recipe),
                      ),
                      InfoPill(
                        icon: difficultyIcon(recipe.difficulty),
                        label: recipe.difficulty.label,
                      ),
                      InfoPill(
                        icon: Icons.people_outline,
                        label: '$servings ที่',
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Space.md),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: p.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ส่วนผสม', style: t.titleSmall),
                        const SizedBox(height: Space.xs),
                        for (final i in ingredients)
                          Row(
                            children: [
                              Expanded(
                                child: Text('• ${i.name}', style: t.bodyMedium),
                              ),
                              Text(i.amountLabel(factor), style: t.bodySmall),
                            ],
                          ),
                        if (recipe.ingredients.length > ingredients.length)
                          Text(
                            'และอีก ${recipe.ingredients.length - ingredients.length} รายการ',
                            style: t.bodySmall,
                          ),
                        const SizedBox(height: Space.sm),
                        Text('วิธีทำ', style: t.titleSmall),
                        const SizedBox(height: Space.xs),
                        for (var i = 0; i < steps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '${i + 1}. ${steps[i]}',
                              style: t.bodyMedium,
                            ),
                          ),
                        if (recipe.steps.length > steps.length)
                          Text('…ดูต่อในแอป', style: t.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Row(
                    children: [
                      const BrandLogo(size: 32),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppConstants.appName, style: t.labelLarge),
                            Text(
                              AppConstants.tagline,
                              style: t.bodySmall!.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        recipe.sourceLabel,
                        style: t.labelSmall!.copyWith(color: p.accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
