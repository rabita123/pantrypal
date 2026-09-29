import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/add_flow.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/domain/services/cook_tonight_service.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/recipes/presentation/widgets/recipe_match_card.dart';

/// Every recipe ranked by how well it uses what is in the pantry — expiring
/// food first, fewest shopping trips second.
class CookTonightPage extends StatelessWidget {
  const CookTonightPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Cook tonight'),
        backgroundColor: AppColors.surface,
      ),
      body: BlocBuilder<PantryBloc, PantryState>(
        builder: (context, pantryState) {
          return BlocBuilder<RecipeBloc, RecipeState>(
            builder: (context, recipeState) {
              final pantryItems = pantryState is PantryLoaded ? pantryState.allItems : <PantryItem>[];
              final recipes = recipeState is RecipeLoaded ? recipeState.all : <Recipe>[];
              final results = CookTonightService.match(recipes: recipes, pantryItems: pantryItems);

              if (results.isEmpty) {
                return _Empty(pantryEmpty: pantryItems.isEmpty);
              }
              return _Results(results: results);
            },
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool pantryEmpty;
  const _Empty({required this.pantryEmpty});

  @override
  Widget build(BuildContext context) {
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
              pantryEmpty ? 'Add food to see what you can cook' : 'No recipe fits yet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              pantryEmpty
                  ? 'Scan a receipt or tap what you have — recipes appear instantly.'
                  : 'None of your recipes use what is in your pantry. Add a few more foods.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.inkMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => AddFlow.start(context),
              icon: const Icon(Icons.add),
              label: const Text('Add food'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  final List<CookTonightResult> results;
  const _Results({required this.results});

  @override
  Widget build(BuildContext context) {
    final canCook = results.where((r) => r.canCookNow).toList();
    final partial = results.where((r) => !r.canCookNow).toList();

    return CustomScrollView(
      slivers: [
        if (canCook.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: SectionLabel(label: 'Ready to cook', icon: Icons.check_circle_outline, color: AppColors.primary),
          ),
          SliverList.builder(
            itemCount: canCook.length,
            itemBuilder: (context, i) => RecipeMatchCard(result: canCook[i]),
          ),
        ],
        if (partial.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: SectionLabel(label: 'Nearly — a few things to buy', icon: Icons.shopping_cart_outlined, color: AppColors.expiringSoon),
          ),
          SliverList.builder(
            itemCount: partial.length,
            itemBuilder: (context, i) => RecipeMatchCard(result: partial[i]),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const SectionLabel({super.key, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
