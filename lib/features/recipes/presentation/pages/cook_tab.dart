import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/kids/presentation/pages/kids_meal_planner_page.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/add_flow.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/domain/services/cook_tonight_service.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/recipes/presentation/pages/ai_recipe_page.dart';
import 'package:pantrypal/features/recipes/presentation/pages/cook_tonight_page.dart';
import 'package:pantrypal/features/recipes/presentation/pages/recipes_page.dart';
import 'package:pantrypal/features/recipes/presentation/widgets/recipe_match_card.dart';
import 'package:pantrypal/features/subscription/presentation/paywall_gate.dart';

/// The Cook tab: starts from the food that needs using, not from a recipe
/// catalogue. Browsing every recipe is one step away, not the front door.
class CookTab extends StatefulWidget {
  const CookTab({super.key});

  @override
  State<CookTab> createState() => _CookTabState();
}

class _CookTabState extends State<CookTab> {
  @override
  void initState() {
    super.initState();
    context.read<RecipeBloc>().add(RecipeLoad());
  }

  Future<void> _openAiRecipe(List<PantryItem> pantry) async {
    if (!await PaywallGate.ensureRecipeAllowed(context) || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AIRecipePage(pantryItems: pantry)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: BlocBuilder<PantryBloc, PantryState>(
        builder: (context, pantryState) {
          return BlocBuilder<RecipeBloc, RecipeState>(
            builder: (context, recipeState) {
              final pantry = pantryState is PantryLoaded ? pantryState.allItems : <PantryItem>[];
              final recipes = recipeState is RecipeLoaded ? recipeState.all : <Recipe>[];
              final results = CookTonightService.match(recipes: recipes, pantryItems: pantry);
              final top = results.take(4).toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: Text(
                      'What to cook',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkInk : AppColors.ink,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      pantry.isEmpty
                          ? 'Add what you have and dinner ideas appear here.'
                          : 'Ranked by what will spoil soonest.',
                      style: TextStyle(color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted, fontSize: 14),
                    ),
                  ),
                  if (pantry.isEmpty)
                    _EmptyCook(onAdd: () => AddFlow.start(context))
                  else if (top.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Text(
                        'No recipe matches your pantry yet. Try the AI recipe below or add more food.',
                        style: TextStyle(color: AppColors.inkMuted, height: 1.5),
                      ),
                    )
                  else ...[
                    for (final r in top) RecipeMatchCard(result: r),
                    if (results.length > top.length)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CookTonightPage()),
                          ),
                          child: Text('See all ${results.length} matches'),
                        ),
                      ),
                  ],
                  if (pantry.isNotEmpty)
                    _ToolCard(
                      emoji: '✨',
                      title: 'Rescue recipe with AI',
                      subtitle: 'Made from the food that expires first',
                      color: AppColors.primary,
                      isDark: isDark,
                      onTap: () => _openAiRecipe(pantry),
                    ),
                  _ToolCard(
                    emoji: '📖',
                    title: 'Browse all recipes',
                    subtitle: 'Search, filter and save your own',
                    color: AppColors.inkMuted,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecipesPage()),
                    ),
                  ),
                  _ToolCard(
                    emoji: '👨‍👩‍👧',
                    title: 'Kids meal planner',
                    subtitle: "Plan the week's meals for little ones",
                    color: const Color(0xFFFF8F00),
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const KidsMealPlannerPage()),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyCook extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCook({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Text('🍳', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            const Text('Nothing to cook with yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
            const SizedBox(height: 6),
            const Text(
              'Scan a receipt or tap what you have — it takes about ten seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.primaryDark, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add food'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _ToolCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkInk : AppColors.ink,
                          )),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
