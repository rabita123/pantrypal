import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/domain/services/cook_tonight_service.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/recipes/presentation/pages/recipe_detail_page.dart';

class CookTonightPage extends StatelessWidget {
  const CookTonightPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pantryState = context.read<PantryBloc>().state;
    final recipeState = context.read<RecipeBloc>().state;

    final pantryItems = pantryState is PantryLoaded ? pantryState.items : <PantryItem>[];
    final recipes = recipeState is RecipeLoaded ? recipeState.all : <Recipe>[];

    final results = CookTonightService.match(recipes: recipes, pantryItems: pantryItems);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Cook Tonight'),
        backgroundColor: AppColors.surface,
      ),
      body: results.isEmpty
          ? _buildEmpty(context, recipes.isEmpty)
          : _buildResults(context, results),
    );
  }

  Widget _buildEmpty(BuildContext context, bool noRecipes) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.dinner_dining_outlined, size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              noRecipes ? 'No recipes yet' : 'No matches found',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              noRecipes
                  ? 'Add some recipes first, then come back to see what you can cook with your pantry.'
                  : 'Your pantry items don\'t match any recipe ingredients yet. Try adding more items or recipes.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.inkMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, List<CookTonightResult> results) {
    final canCook = results.where((r) => r.canCookNow).toList();
    final partial = results.where((r) => !r.canCookNow).toList();

    return CustomScrollView(
      slivers: [
        // Header banner
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🍳', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canCook.isNotEmpty
                            ? '${canCook.length} recipe${canCook.length == 1 ? '' : 's'} ready to cook!'
                            : 'Almost there!',
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Based on ${results.first.totalCount > 0 ? "your pantry" : "your items"}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Ready to cook section
        if (canCook.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionHeader(label: 'Ready to cook', icon: Icons.check_circle_outline, color: AppColors.primary)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _RecipeMatchCard(result: canCook[i]),
              childCount: canCook.length,
            ),
          ),
        ],

        // Partial match section
        if (partial.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionHeader(label: 'Almost — a few items missing', icon: Icons.shopping_cart_outlined, color: AppColors.expiringSoon)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _RecipeMatchCard(result: partial[i]),
              childCount: partial.length,
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _RecipeMatchCard extends StatelessWidget {
  final CookTonightResult result;
  const _RecipeMatchCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recipe = result.recipe;
    final pct = (result.matchPercent * 100).round();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<RecipeBloc>()),
            ],
            child: RecipeDetailPage(recipe: recipe),
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Match % ring
                  _MatchRing(percent: result.matchPercent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkInk : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 8,
                          children: [
                            _chip(Icons.timer_outlined, recipe.timeLabel),
                            _chip(Icons.restaurant_outlined, recipe.cuisine.label),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.inkLight),
                ],
              ),

              // Expiring badge
              if (result.expiringCount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.expiringSoonSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 13, color: AppColors.expiringSoon),
                      const SizedBox(width: 4),
                      Text(
                        'Uses ${result.expiringCount} expiring item${result.expiringCount > 1 ? 's' : ''} — cook soon!',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.expiringSoon),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Ingredient dots
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: result.matches.map((m) => _IngDot(match: m)).toList(),
              ),

              // Missing summary
              if (result.foundCount < result.totalCount) ...[
                const SizedBox(height: 8),
                Text(
                  '$pct% match · missing ${result.totalCount - result.foundCount} ingredient${result.totalCount - result.foundCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.inkMuted),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
      ],
    );
  }
}

class _IngDot extends StatelessWidget {
  final IngredientMatch match;
  const _IngDot({required this.match});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color text;
    final IconData icon;

    if (!match.found) {
      bg = AppColors.border;
      text = AppColors.inkMuted;
      icon = Icons.close;
    } else if (match.expiringSoon) {
      bg = AppColors.expiringSoonSurface;
      text = AppColors.expiringSoon;
      icon = Icons.timer_outlined;
    } else {
      bg = AppColors.primarySurface;
      text = AppColors.primary;
      icon = Icons.check;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: text),
          const SizedBox(width: 3),
          Text(
            match.ingredientName,
            style: TextStyle(fontSize: 11, color: text, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MatchRing extends StatelessWidget {
  final double percent;
  const _MatchRing({required this.percent});

  @override
  Widget build(BuildContext context) {
    final color = percent >= 0.8
        ? AppColors.primary
        : percent >= 0.5
            ? AppColors.expiringSoon
            : AppColors.inkLight;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percent,
            strokeWidth: 5,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            '${(percent * 100).round()}%',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
