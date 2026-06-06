import 'package:flutter/material.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/data/ai_recipe_service.dart';

class AIRecipePage extends StatefulWidget {
  final List<PantryItem> pantryItems;
  const AIRecipePage({super.key, required this.pantryItems});

  @override
  State<AIRecipePage> createState() => _AIRecipePageState();
}

class _AIRecipePageState extends State<AIRecipePage> {
  AIRecipe? _recipe;
  bool _loading = true;
  String _error = '';
  int _msgIndex = 0;

  static const _messages = [
    'Looking at your pantry… 🧑‍🍳',
    'Prioritising expiring items… ⏰',
    'Crafting the perfect recipe… ✨',
    'Almost ready… 🍽️',
  ];

  @override
  void initState() {
    super.initState();
    _generate();
    _rotateMsgs();
  }

  void _rotateMsgs() async {
    for (var i = 1; i < _messages.length; i++) {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted || !_loading) return;
      setState(() => _msgIndex = i);
    }
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = ''; _msgIndex = 0; });
    try {
      final recipe = await AIRecipeService.generate(widget.pantryItems);
      if (!mounted) return;
      setState(() { _recipe = recipe; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
      appBar: AppBar(
        title: const Text('Smart Recipe'),
        backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (!_loading)
            TextButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try another'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
      ),
      body: _loading
          ? _LoadingView(message: _messages[_msgIndex])
          : _error.isNotEmpty
              ? _ErrorView(message: _error, onRetry: _generate)
              : _RecipeView(recipe: _recipe!, isDark: isDark),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 5),
          ),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              message,
              key: ValueKey(message),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Your personal chef is working the magic ✨', style: TextStyle(fontSize: 13, color: AppColors.inkLight)),
        ],
      ),
    );
  }
}

// ── Recipe ────────────────────────────────────────────────────────────────────

class _RecipeView extends StatelessWidget {
  final AIRecipe recipe;
  final bool isDark;
  const _RecipeView({required this.recipe, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.emoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  recipe.name,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  recipe.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _InfoChip(icon: Icons.timer_outlined, label: 'Prep ${recipe.prepTime}'),
                    const SizedBox(width: 10),
                    _InfoChip(icon: Icons.local_fire_department_outlined, label: 'Cook ${recipe.cookTime}'),
                    const SizedBox(width: 10),
                    _InfoChip(icon: Icons.people_outline, label: '${recipe.servings} servings'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Uses expiring badge
          if (recipe.usesExpiring.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.expiringSoonSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: AppColors.expiringSoon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Uses your expiring: ${recipe.usesExpiring.join(', ')}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.expiringSoon),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Ingredients
          _SectionTitle(title: 'Ingredients', isDark: isDark),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Column(
              children: recipe.ingredients.asMap().entries.map((e) {
                final isLast = e.key == recipe.ingredients.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(
                      bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.value.item,
                          style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkInk : AppColors.ink),
                        ),
                      ),
                      Text(
                        e.value.amount,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Steps
          _SectionTitle(title: 'Instructions', isDark: isDark),
          const SizedBox(height: 10),
          ...recipe.steps.asMap().entries.map((e) => _StepCard(
            number: e.key + 1,
            text: e.value,
            isDark: isDark,
          )),

          // Chef tip
          if (recipe.tip.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chef\'s Tip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        const SizedBox(height: 4),
                        Text(recipe.tip, style: const TextStyle(fontSize: 13, color: AppColors.primary, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white70),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkInk : AppColors.ink),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number;
  final String text;
  final bool isDark;
  const _StepCard({required this.number, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? AppColors.darkInk : AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😕', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            const Text('Could not generate recipe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.inkMuted, height: 1.5)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
