import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/shopping_cubit.dart';
import 'package:pantrypal/features/recipes/domain/services/cook_tonight_service.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/recipes/presentation/pages/recipe_detail_page.dart';

/// A recipe scored against the pantry: what you have, what is about to expire,
/// and — the part that saves money — exactly what is missing, one tap from the
/// shopping list.
class RecipeMatchCard extends StatelessWidget {
  final CookTonightResult result;
  const RecipeMatchCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recipe = result.recipe;
    final missing = result.missingNames;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: context.read<RecipeBloc>(),
            child: RecipeDetailPage(recipe: recipe),
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: result.expiringCount > 0
                ? AppColors.expiringSoon.withValues(alpha: 0.45)
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                        Text(
                          result.canCookNow
                              ? 'You have everything · ${recipe.timeLabel}'
                              : 'Missing ${result.missingCount} · ${recipe.timeLabel}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: result.canCookNow ? AppColors.primary : AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.inkLight),
                ],
              ),
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
                        'Uses ${result.expiringCount} item${result.expiringCount > 1 ? 's' : ''} that expire soon',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.expiringSoon),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: result.matches.where((m) => !m.isStaple).map((m) => _IngDot(match: m)).toList(),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final added = await context.read<ShoppingCubit>().addNames(missing);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: Text(added == 0
                              ? 'Already on your shopping list'
                              : 'Added $added to your shopping list'),
                          duration: const Duration(seconds: 2),
                        ));
                    },
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: Text('Add ${missing.length} missing to list'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
