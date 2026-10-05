import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/config/backend_config.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/core/utils/food_emoji.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/shopping_cubit.dart';
import 'package:pantrypal/features/plan/data/rescue_service.dart';
import 'package:pantrypal/features/plan/domain/meal_planner.dart';
import 'package:pantrypal/features/plan/presentation/plan_cubit.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/subscription/presentation/paywall_gate.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';
import 'package:pantrypal/injection_container.dart';
import 'package:pantrypal/shared/services/ai_consent.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';

/// Leftover Rescue: pick what needs using, get three practical meals built
/// around it, and put one on tonight's plan in a tap.
class LeftoverRescuePage extends StatefulWidget {
  const LeftoverRescuePage({super.key});

  @override
  State<LeftoverRescuePage> createState() => _LeftoverRescuePageState();
}

class _LeftoverRescuePageState extends State<LeftoverRescuePage> {
  final _picked = <String>{};
  bool _seeded = false;
  bool _loading = false;
  String? _error;
  List<RescueIdea> _ideas = const [];
  final _added = <String>{};

  List<PantryItem> _candidates(List<PantryItem> all) => all
      .where((p) => p.isActive && p.daysUntilExpiry >= 0)
      .toList()
    ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

  Future<void> _go(List<PantryItem> pantry) async {
    if (_picked.isEmpty || _loading) return;
    if (!await AiConsent.ensure(context) || !mounted) return;
    if (!await PaywallGate.ensureRecipeAllowed(context) || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _ideas = const [];
    });
    final picked = pantry.where((p) => _picked.contains(p.id)).toList();
    final started = DateTime.now();
    try {
      final ideas = await RescueService.ideas(
        picked: picked,
        pantry: pantry,
        servings: context.read<PlanCubit>().state.household,
      );
      await sl<SubscriptionService>().recordRecipeGenerated();
      Analytics.track('rescue_ideas', {
        'picked': picked.length,
        'ideas': ideas.length,
        'ms': DateTime.now().difference(started).inMilliseconds,
      });
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _ideas = ideas);
    } catch (e) {
      Analytics.track('rescue_failed');
      if (mounted) setState(() => _error = BackendException.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cookTonight(RescueIdea idea) async {
    context.read<RecipeBloc>().add(RecipeSave(idea.recipe));
    await context.read<PlanCubit>().addMeal(idea.recipe);
    if (!mounted) return;
    setState(() => _added.add(idea.recipe.id));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.primary,
      content: Text('${idea.recipe.name} is on tonight\'s plan'),
    ));
  }

  Future<void> _addMissing(List<String> names) async {
    final n = await context.read<ShoppingCubit>().addNames(names);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(n == 0 ? 'Already on your shopping list' : 'Added $n to your shopping list'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;
    final pantryState = context.watch<PantryBloc>().state;
    final pantry = pantryState is PantryLoaded ? pantryState.allItems : <PantryItem>[];
    final candidates = _candidates(pantry);

    // Start with what is closest to going off.
    if (!_seeded && candidates.isNotEmpty) {
      _seeded = true;
      _picked.addAll(candidates.where((p) => p.daysUntilExpiry <= 3).take(6).map((p) => p.id));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
      appBar: AppBar(title: const Text('Leftover rescue')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text('Pick what needs using. We\'ll suggest 3 meals built around it.',
              style: TextStyle(fontSize: 14, color: muted, height: 1.4)),
          const SizedBox(height: 14),
          if (candidates.isEmpty)
            Text('Your pantry is empty — add food first.', style: TextStyle(color: muted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in candidates.take(30))
                  FilterChip(
                    avatar: Text(foodEmoji(p.name, p.category)),
                    label: Text(p.daysUntilExpiry <= 3 ? '${p.name} · ${p.daysUntilExpiry}d' : p.name),
                    selected: _picked.contains(p.id),
                    selectedColor: p.daysUntilExpiry <= 3 ? AppColors.expiringSoonSurface : AppColors.primarySurface,
                    onSelected: (v) => setState(() => v ? _picked.add(p.id) : _picked.remove(p.id)),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _picked.isEmpty || _loading ? null : () => _go(pantry),
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _loading ? 'Thinking…' : (_ideas.isEmpty ? 'Get 3 ideas' : 'Get 3 new ideas'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.expiredSurface, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: const TextStyle(color: AppColors.expired, fontWeight: FontWeight.w600)),
            ),
          if (_loading) for (var i = 0; i < 3; i++) const _Skeleton(),
          for (var i = 0; i < _ideas.length; i++)
            _IdeaCard(
              idea: _ideas[i],
              order: i,
              option: MealPlanner.evaluateSequence([_ideas[i].recipe], pantry).single,
              added: _added.contains(_ideas[i].recipe.id),
              onCook: () => _cookTonight(_ideas[i]),
              onAddMissing: _addMissing,
              ink: ink,
              muted: muted,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  final RescueIdea idea;
  final int order;
  final MealOption option;
  final bool added;
  final VoidCallback onCook;
  final void Function(List<String>) onAddMissing;
  final Color ink, muted;
  final bool isDark;

  const _IdeaCard({
    required this.idea,
    required this.order,
    required this.option,
    required this.added,
    required this.onCook,
    required this.onAddMissing,
    required this.ink,
    required this.muted,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final r = idea.recipe;
    final uses = option.usedItems;
    final missing = option.missingNames;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + order * 90),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            leading: Text(idea.emoji, style: const TextStyle(fontSize: 30)),
            title: Text(r.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [r.timeLabel, 'serves ${r.servings}', if (missing.isEmpty) 'no shopping'].join(' · '),
                    style: TextStyle(fontSize: 13, color: missing.isEmpty ? AppColors.primary : muted, fontWeight: FontWeight.w600),
                  ),
                  if (r.nutritionLabel != null)
                    Text('${r.nutritionLabel} per serving (estimate)', style: TextStyle(fontSize: 12, color: muted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in uses)
                        _Tag(p.name,
                            p.daysUntilExpiry <= 3 ? AppColors.expiringSoonSurface : AppColors.primarySurface,
                            p.daysUntilExpiry <= 3 ? AppColors.expiringSoon : AppColors.primary,
                            p.daysUntilExpiry <= 3 ? Icons.timer_outlined : Icons.check),
                      for (final m in missing) _Tag(m, AppColors.border, AppColors.inkMuted, Icons.add_shopping_cart),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: added ? null : onCook,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primarySurface,
                          foregroundColor: AppColors.primaryDark,
                          minimumSize: const Size(0, 38),
                        ),
                        child: Text(added ? 'On tonight\'s plan ✓' : 'Cook tonight',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      if (missing.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        TextButton(onPressed: () => onAddMissing(missing), child: const Text('Add missing')),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            children: [
              if (r.description != null && r.description!.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(r.description!, style: TextStyle(fontSize: 14, color: muted, height: 1.4)),
                ),
              const SizedBox(height: 8),
              for (var i = 0; i < r.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.steps[i], style: TextStyle(fontSize: 14, color: ink, height: 1.4))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg, fg;
  final IconData icon;
  const _Tag(this.text, this.bg, this.fg, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ]),
      );
}

/// Placeholder while the ideas are being written — shows the shape of what
/// is coming instead of a spinner.
class _Skeleton extends StatefulWidget {
  const _Skeleton();
  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.darkBorder : AppColors.border;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final c = Color.lerp(base, base.withValues(alpha: 0.4), _c.value)!;
        Widget bar(double w, double h) =>
            Container(width: w, height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)));
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: base),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(36, 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [bar(180, 16), const SizedBox(height: 8), bar(120, 12), const SizedBox(height: 10), bar(220, 22)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
