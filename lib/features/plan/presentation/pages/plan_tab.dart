import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/add_flow.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/shopping_cubit.dart';
import 'package:pantrypal/features/plan/data/plan_repository.dart';
import 'package:pantrypal/core/config/backend_config.dart';
import 'package:pantrypal/features/plan/data/rescue_service.dart';
import 'package:pantrypal/features/plan/domain/meal_planner.dart';
import 'package:pantrypal/features/plan/domain/plan_filler.dart';
import 'package:pantrypal/shared/services/ai_consent.dart';
import 'package:pantrypal/features/plan/presentation/pages/batch_cook_page.dart';
import 'package:pantrypal/features/plan/presentation/pages/leftover_rescue_page.dart';
import 'package:pantrypal/features/plan/presentation/plan_cubit.dart';
import 'package:pantrypal/features/plan/presentation/widgets/plan_widgets.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/recipes/presentation/pages/recipe_detail_page.dart';
import 'package:pantrypal/features/recipes/presentation/pages/recipes_page.dart';
import 'package:pantrypal/features/subscription/bloc/subscription_cubit.dart';
import 'package:pantrypal/features/subscription/presentation/paywall_gate.dart';
import 'package:pantrypal/features/subscription/presentation/paywall_page.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';

/// Plan meals from what you already have → batch cook → portions.
class PlanTab extends StatefulWidget {
  const PlanTab({super.key});

  @override
  State<PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<PlanTab> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context.read<RecipeBloc>().add(RecipeLoad());
  }

  Future<void> _createPlan(List<Recipe> recipes, List<PantryItem> pantry, int days) async {
    if (_busy) return;
    if (days > SubscriptionService.freePlanDays &&
        !await PaywallGate.ensurePremium(context, PaywallReason.weekPlan)) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    final cubit = context.read<PlanCubit>();
    final before = [
      for (final m in cubit.state.regular)
        if (m.status == MealStatus.planned) m.recipeId,
    ];
    var draft = MealPlanner.plan(recipes: recipes, pantry: pantry, days: days);

    // Premium week: when the built-in recipes run out, fill the remaining
    // days with AI meals made from the user's own food.
    var aiAdded = 0;
    String? aiProblem;
    if (days > SubscriptionService.freePlanDays && draft.length < days && pantry.isNotEmpty) {
      if (await AiConsent.ensure(context) && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Adding AI meal ideas for the rest of the week…'),
            duration: Duration(seconds: 20),
          ));
        try {
          final res = await PlanFiller.fill(
            draft: draft,
            days: days,
            pantry: pantry,
            start: DateTime.now(),
            existingNames: {for (final r in recipes) r.name},
            ideas: (picked) async => (await RescueService.ideas(
              picked: picked,
              pantry: pantry,
              servings: cubit.state.household,
              mode: 'plan',
              avoid: draft.map((d) => d.option.recipe.name),
            ))
                .map((i) => i.recipe)
                .toList(),
          );
          if (!mounted) return;
          final recipeBloc = context.read<RecipeBloc>();
          for (final r in res.added) {
            recipeBloc.add(RecipeSave(r));
          }
          draft = res.plan;
          aiAdded = res.added.length;
          Analytics.track('plan_ai_filled', {'added': aiAdded, 'days': days});
        } catch (e) {
          aiProblem = BackendException.from(e).message;
        }
        messenger.hideCurrentSnackBar();
      }
    }

    await cubit.savePlan(draft);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _busy = false);

    if (aiAdded > 0 || aiProblem != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(aiProblem != null
              ? 'Planned ${draft.length} day${draft.length == 1 ? '' : 's'}. AI couldn\'t add more right now — try again later.'
              : 'Planned ${draft.length} days · $aiAdded AI meal idea${aiAdded == 1 ? '' : 's'} from your food'),
        ));
      return;
    }

    // Say what happened — an identical plan otherwise looks like a dead button.
    if (before.isEmpty) return; // first plan: the new cards speak for themselves
    final after = draft.map((d) => d.option.recipe.id).toList();
    final changed = after.where((id) => !before.contains(id)).length + (before.length - after.length).clamp(0, 99);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(draft.isEmpty
            ? 'Your pantry can\'t make a full meal right now — add a few more foods'
            : changed == 0
                ? 'Already the best plan for what you have. Tap Swap to try a different meal.'
                : 'Plan updated · $changed meal${changed == 1 ? '' : 's'} changed'),
      ));
  }

  Future<void> _addMissing(List<String> names) async {
    final added = await context.read<ShoppingCubit>().addNames(names);
    Analytics.track('plan_missing_added', {'count': added});
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(added == 0 ? 'Already on your shopping list' : 'Added $added to your shopping list'),
      ));
  }

  Future<void> _openBatch() async {
    if (!await PaywallGate.ensurePremium(context, PaywallReason.batchCook) || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const BatchCookPage()));
  }

  void _openRecipe(Recipe r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(value: context.read<RecipeBloc>(), child: RecipeDetailPage(recipe: r)),
      ),
    );
  }

  Future<void> _household(int current) async {
    var n = current;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Cooking for', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.outlined(onPressed: n > 1 ? () => set(() => n--) : null, icon: const Icon(Icons.remove)),
                    SizedBox(
                      width: 110,
                      child: Text('$n ${n == 1 ? 'person' : 'people'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    IconButton.outlined(onPressed: n < 12 ? () => set(() => n++) : null, icon: const Icon(Icons.add)),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(onPressed: () => Navigator.pop(ctx, n), child: const Text('Done')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null && mounted) context.read<PlanCubit>().setHousehold(picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;

    return SafeArea(
      child: BlocBuilder<PantryBloc, PantryState>(
        builder: (context, pantryState) => BlocBuilder<RecipeBloc, RecipeState>(
          builder: (context, recipeState) => BlocBuilder<PlanCubit, PlanState>(
            builder: (context, plan) {
              final pantry = pantryState is PantryLoaded ? pantryState.allItems : <PantryItem>[];
              final recipes = recipeState is RecipeLoaded ? recipeState.all : <Recipe>[];
              final byId = {for (final r in recipes) r.id: r};
              final sub = context.watch<SubscriptionCubit>().state;
              final premium = SubscriptionService.premiumPreview || (sub is SubscriptionReady && sub.isPremium);

              // What the pantry could cover this week — the honest headline.
              final week = MealPlanner.plan(recipes: recipes, pantry: pantry, days: 7);

              // The saved plan, re-checked against today's pantry in order.
              final regular = plan.regular;
              final toEvaluate = [
                for (final m in regular)
                  if (m.status == MealStatus.planned && byId[m.recipeId] != null) m,
              ];
              final evaluated = MealPlanner.evaluateSequence(
                  [for (final m in toEvaluate) byId[m.recipeId]!], pantry);
              final optionFor = {for (var i = 0; i < toEvaluate.length; i++) toEvaluate[i].id: evaluated[i]};
              final batchToday = plan.batch;
              final batchOptions = {
                for (final m in batchToday)
                  if (byId[m.recipeId] != null) m.id: MealPlanner.evaluateSequence([byId[m.recipeId]!], pantry).single,
              };

              return ListView(
                padding: const EdgeInsets.only(bottom: 110),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 12, 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Plan',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink)),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.people_outline, size: 18),
                          label: Text('For ${plan.household}'),
                          onPressed: () => _household(plan.household),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text('Meals from what you already have.', style: TextStyle(fontSize: 14, color: muted)),
                  ),

                  if (plan.portions.isNotEmpty) PortionsSection(portions: plan.portions),

                  if (batchToday.isNotEmpty) ...[
                    _SectionTitle('Batch cook today'),
                    for (final m in batchToday)
                      PlanMealCard(
                        meal: m,
                        option: batchOptions[m.id],
                        label: 'Batch · ${m.freezePortions > 0 ? '${m.freezePortions} to freeze' : 'fridge'}',
                        onOpen: byId[m.recipeId] == null ? null : () => _openRecipe(byId[m.recipeId]!),
                        onCooked: () => CookSheet.show(context, meal: m, option: batchOptions[m.id], household: plan.household),
                        onRemove: () => context.read<PlanCubit>().removeMeal(m),
                      ),
                  ],

                  if (pantry.isEmpty)
                    _Empty(onAdd: () => AddFlow.start(context))
                  else if (regular.isEmpty) ...[
                    PlanSummaryCard(
                      headline: week.isEmpty
                          ? 'Your pantry can\'t make a full meal yet'
                          : 'Your pantry can make ${week.length} meal${week.length == 1 ? '' : 's'} this week',
                      insight: MealPlanner.insight(
                        meals: week.map((d) => d.option).toList(),
                        pantry: pantry,
                        mealsPossible: week.length,
                      ),
                      action: week.isEmpty
                          ? _Wide(label: 'Add more food', onTap: () => AddFlow.start(context))
                          : Column(
                              children: [
                                _Wide(
                                  label: _busy
                                      ? 'Planning…'
                                      : premium
                                          ? 'Plan my week'
                                          : 'Plan my next ${week.length.clamp(1, SubscriptionService.freePlanDays)} days',
                                  onTap: () => _createPlan(
                                    recipes,
                                    pantry,
                                    premium ? SubscriptionService.premiumPlanDays : SubscriptionService.freePlanDays,
                                  ),
                                ),
                                if (!premium)
                                  TextButton(
                                    onPressed: () => _createPlan(recipes, pantry, SubscriptionService.premiumPlanDays),
                                    child: const Text('Plan all 7 days · Premium'),
                                  ),
                              ],
                            ),
                    ),
                  ] else ...[
                    PlanSummaryCard(
                      headline: '${regular.length} meal${regular.length == 1 ? '' : 's'} planned from your pantry',
                      insight: MealPlanner.insight(meals: evaluated, pantry: pantry, mealsPossible: week.length),
                      onAddMissing: () {
                        final names = MealPlanner.insight(meals: evaluated, pantry: pantry, mealsPossible: 0).toBuy;
                        _addMissing(names);
                      },
                    ),
                    for (final m in regular)
                      PlanMealCard(
                        meal: m,
                        option: optionFor[m.id],
                        onOpen: byId[m.recipeId] == null ? null : () => _openRecipe(byId[m.recipeId]!),
                        onCooked: () => CookSheet.show(context, meal: m, option: optionFor[m.id], household: plan.household),
                        onRemove: () => context.read<PlanCubit>().removeMeal(m),
                        onSwap: () {
                          final others = [
                            for (final o in toEvaluate)
                              if (o.id != m.id && byId[o.recipeId] != null) byId[o.recipeId]!,
                          ];
                          final alt = MealPlanner.alternative(
                            recipes: recipes,
                            pantry: pantry,
                            otherMeals: others,
                            exclude: {for (final o in regular) o.recipeId},
                          );
                          if (alt == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No other meal fits your pantry right now')),
                            );
                          } else {
                            context.read<PlanCubit>().swapMeal(m, alt);
                          }
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton.icon(
                        onPressed: () => _createPlan(
                          recipes,
                          pantry,
                          premium ? SubscriptionService.premiumPlanDays : SubscriptionService.freePlanDays,
                        ),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Re-plan from today\'s pantry'),
                      ),
                    ),
                  ],

                  if (pantry.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _ToolCard(
                      emoji: '🥘',
                      title: 'Batch cook',
                      subtitle: 'Cook once → portions for the fridge and freezer',
                      badge: premium ? null : 'PREMIUM',
                      highlight: true,
                      onTap: _openBatch,
                    ),
                    _ToolCard(
                      emoji: '✨',
                      title: 'Leftover rescue',
                      subtitle: 'Pick what needs using — get 3 meal ideas',
                      badge: premium ? null : '1 FREE / WEEK',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LeftoverRescuePage()),
                      ),
                    ),
                  ],
                  _ToolCard(
                    emoji: '📖',
                    title: 'All recipes',
                    subtitle: 'Search, filter and save your own',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipesPage())),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        child: Text(text,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : AppColors.ink,
            )),
      );
}

class _Wide extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Wide({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      );
}

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            const Text('🗓️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            const Text('Add food to plan your meals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
            const SizedBox(height: 6),
            const Text(
              'Your plan is built from what is in your kitchen — scan a receipt and it fills in.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.primaryDark, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add food')),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final String? badge;
  final bool highlight;
  final VoidCallback onTap;
  const _ToolCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: highlight ? AppColors.primarySurface : (isDark ? AppColors.darkCard : AppColors.card),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlight ? AppColors.primary.withValues(alpha: 0.5) : (isDark ? AppColors.darkBorder : AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkInk : AppColors.ink,
                              )),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                              child: Text(badge!,
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.6)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.inkLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
