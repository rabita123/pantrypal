import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/recipes/presentation/pages/add_recipe_page.dart';

class RecipeDetailPage extends StatefulWidget {
  final Recipe recipe;
  const RecipeDetailPage({super.key, required this.recipe});

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  late int _servings;

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.servings;
  }

  double get _scale => _servings / widget.recipe.servings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recipe = widget.recipe;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                ),
                onPressed: () {
                  context.read<RecipeBloc>().add(RecipeToggleFavorite(recipe.id));
                  Navigator.pop(context);
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () => _openEdit(context, recipe),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: () => _confirmDelete(context, recipe),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                recipe.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.menu_book_outlined, size: 64, color: Colors.white24),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MetaChip(Icons.timer_outlined, recipe.timeLabel),
                      _MetaChip(Icons.restaurant_outlined, recipe.cuisine.label),
                      _MetaChip(Icons.egg_outlined, '${recipe.ingredients.length} ingredients'),
                    ],
                  ),

                  // Description
                  if (recipe.description != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      recipe.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
                        height: 1.5,
                      ),
                    ),
                  ],

                  // Dietary tags
                  if (recipe.dietaryTags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: recipe.dietaryTags.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${t.emoji} ${t.label}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Portion scaler ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people_outline, size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Servings',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkInk : AppColors.ink,
                              ),
                            ),
                            const Spacer(),
                            if (_scale != 1.0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '×${_scale.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ScalerBtn(
                              icon: Icons.remove,
                              onTap: _servings > 1
                                  ? () => setState(() => _servings--)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '$_servings',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkInk : AppColors.ink,
                              ),
                            ),
                            const SizedBox(width: 16),
                            _ScalerBtn(
                              icon: Icons.add,
                              onTap: () => setState(() => _servings++),
                            ),
                          ],
                        ),
                        if (_scale != 1.0) ...[
                          const SizedBox(height: 6),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() => _servings = widget.recipe.servings),
                              child: const Text('Reset to original'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Ingredients ─────────────────────────────────────────
                  Text(
                    'Ingredients',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkInk : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...recipe.ingredients.map((ing) {
                    final scaled = ing.scaleBy(_scale);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(ing.category.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ing.name,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.darkInk : AppColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            '${scaled.displayQuantity} ${scaled.unit}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _scale != 1.0 ? AppColors.accent : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // ── Steps ───────────────────────────────────────────────
                  Text(
                    'Instructions',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkInk : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...recipe.steps.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${e.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: isDark ? AppColors.darkInk : AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEdit(BuildContext context, Recipe recipe) async {
    final saved = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<RecipeBloc>(),
          child: AddRecipePage(existing: recipe),
        ),
      ),
    );
    if (saved != null && context.mounted) {
      context.read<RecipeBloc>().add(RecipeSave(saved));
      Navigator.pop(context);
    }
  }

  void _confirmDelete(BuildContext context, Recipe recipe) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Remove "${recipe.name}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<RecipeBloc>().add(RecipeDelete(recipe.id));
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close detail
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.expired)),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ScalerBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _ScalerBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.3 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }
}
