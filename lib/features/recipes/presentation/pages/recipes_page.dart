import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/recipes/presentation/pages/add_recipe_page.dart';
import 'package:pantrypal/features/recipes/presentation/pages/recipe_detail_page.dart';

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<RecipeBloc>().add(RecipeLoad());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAdd,
            tooltip: 'Add recipe',
          ),
        ],
      ),
      body: BlocBuilder<RecipeBloc, RecipeState>(
        builder: (context, state) {
          if (state is RecipeLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (state is RecipeLoaded) {
            return _buildLoaded(context, state, isDark);
          }
          return _buildEmpty(context);
        },
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, RecipeLoaded state, bool isDark) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search recipes…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: state.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        context.read<RecipeBloc>().add(RecipeSearch(''));
                      },
                    )
                  : null,
            ),
            onChanged: (q) => context.read<RecipeBloc>().add(RecipeSearch(q)),
          ),
        ),

        // Dietary filter chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _FilterChip(
                label: '❤️ Favourites',
                active: state.favoritesOnly,
                onTap: () => context.read<RecipeBloc>().add(
                      RecipeSetFilter(favoritesOnly: !state.favoritesOnly),
                    ),
              ),
              ...DietaryTag.values.map((tag) => _FilterChip(
                    label: '${tag.emoji} ${tag.label}',
                    active: state.activeDietary == tag,
                    onTap: () => context.read<RecipeBloc>().add(
                          RecipeSetFilter(
                            dietary: state.activeDietary == tag ? null : tag,
                            cuisine: state.activeCuisine,
                          ),
                        ),
                  )),
            ],
          ),
        ),

        // Cuisine filter
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: Cuisine.values.map((c) => _FilterChip(
                  label: '${c.emoji} ${c.label}',
                  active: state.activeCuisine == c,
                  color: AppColors.accent,
                  onTap: () => context.read<RecipeBloc>().add(
                        RecipeSetFilter(
                          dietary: state.activeDietary,
                          cuisine: state.activeCuisine == c ? null : c,
                        ),
                      ),
                )).toList(),
          ),
        ),

        const SizedBox(height: 4),

        // Recipe list
        Expanded(
          child: state.filtered.isEmpty
              ? _buildEmpty(context)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: state.filtered.length,
                  itemBuilder: (ctx, i) => _RecipeCard(
                    recipe: state.filtered[i],
                    isDark: isDark,
                    onTap: () => _openDetail(state.filtered[i]),
                    onFavorite: () => context
                        .read<RecipeBloc>()
                        .add(RecipeToggleFavorite(state.filtered[i].id)),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.menu_book_outlined, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('No recipes yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Add your favourite recipes — including authentic Bangladeshi dishes no other app has!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.inkMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add first recipe'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAdd() async {
    final saved = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(builder: (_) => BlocProvider.value(
        value: context.read<RecipeBloc>(),
        child: const AddRecipePage(),
      )),
    );
    if (saved != null && mounted) {
      context.read<RecipeBloc>().add(RecipeSave(saved));
    }
  }

  void _openDetail(Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<RecipeBloc>(),
          child: RecipeDetailPage(recipe: recipe),
        ),
      ),
    );
  }
}

// ── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

// ── Recipe card ───────────────────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _RecipeCard({
    required this.recipe,
    required this.isDark,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkInk : AppColors.ink,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onFavorite,
                    child: Icon(
                      recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: recipe.isFavorite ? AppColors.expired : AppColors.inkLight,
                    ),
                  ),
                ],
              ),
              if (recipe.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  recipe.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.inkMuted, height: 1.4),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _meta(Icons.people_outline, '${recipe.servings} servings'),
                  _meta(Icons.timer_outlined, recipe.timeLabel),
                  _meta(Icons.restaurant_outlined, recipe.cuisine.label),
                ],
              ),
              if (recipe.dietaryTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: recipe.dietaryTags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${t.emoji} ${t.label}',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.inkMuted),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
      ],
    );
  }
}
