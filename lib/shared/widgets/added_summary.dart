import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/core/utils/food_emoji.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/domain/services/pantry_insights.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/recipes/data/repositories/recipe_repository.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/recipes/presentation/pages/cook_tonight_page.dart';
import 'package:pantrypal/injection_container.dart';

/// The moment the app proves itself: right after food goes in, say what it
/// found — what to use first, what that is worth, and what to cook.
class AddedSummary extends StatelessWidget {
  final List<PantryItem> added;
  final List<PantryItem> pantry;
  final List<Recipe> recipes;
  final VoidCallback? onCook;

  const AddedSummary({
    super.key,
    required this.added,
    required this.pantry,
    required this.recipes,
    this.onCook,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;

    final urgent = PantryInsights.useFirst(added);
    final atRisk = PantryInsights.atRiskValue(added);
    final pick = PantryInsights.tonightPick(recipes, pantry);
    final approx = added.any((i) => i.isValueEstimated);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${added.length} item${added.length == 1 ? '' : 's'} added',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ink),
        ),
        const SizedBox(height: 12),
        if (urgent.isEmpty)
          _Note(
            icon: Icons.check_circle_outline,
            color: AppColors.primary,
            bg: AppColors.primarySurface,
            text: 'Everything is fresh. We\'ll remind you before anything runs out of time.',
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                icon: Icons.timer_outlined,
                label: '${urgent.length} to use soon',
                color: AppColors.expiringSoon,
                bg: AppColors.expiringSoonSurface,
              ),
              if (atRisk > 0)
                _Pill(
                  icon: Icons.savings_outlined,
                  label: '${PantryInsights.money(atRisk, approx: approx)} at risk',
                  color: AppColors.expired,
                  bg: AppColors.expiredSurface,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Use these first', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: muted)),
          const SizedBox(height: 6),
          for (final item in urgent.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(foodEmoji(item.name, item.category), style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink)),
                  ),
                  Text(
                    PantryInsights.shortWhen(item),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.expiringSoon),
                  ),
                ],
              ),
            ),
        ],
        if (pick != null) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onCook,
            child: Container(
              padding: const EdgeInsets.all(14),
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
                  const Text('🍳', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cook tonight', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                        Text(
                          pick.recipe.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Text(
                          pick.canCookNow ? 'You have everything · ${pick.recipe.timeLabel}' : 'Missing ${pick.missingCount} · ${pick.recipe.timeLabel}',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bottom sheet wrapper shown after any multi-item add.
class AddedSummarySheet {
  static Future<void> show(BuildContext context, List<PantryItem> added) async {
    final recipes = await loadRecipes(context);
    if (!context.mounted) return;
    final pantryState = context.read<PantryBloc>().state;
    final existing = pantryState is PantryLoaded ? pantryState.allItems : <PantryItem>[];
    // The bloc may not have reloaded yet — merge by id so nothing is missing.
    final ids = existing.map((e) => e.id).toSet();
    final pantry = [...existing, ...added.where((a) => !ids.contains(a.id))];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AddedSummary(
                    added: added,
                    pantry: pantry,
                    recipes: recipes,
                    onCook: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CookTonightPage()));
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<List<Recipe>> loadRecipes(BuildContext context) async {
    final s = context.read<RecipeBloc>().state;
    if (s is RecipeLoaded) return s.all;
    return sl<RecipeRepository>().getAll();
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  const _Pill({required this.icon, required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final String text;
  const _Note({required this.icon, required this.color, required this.bg, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color, height: 1.4, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
