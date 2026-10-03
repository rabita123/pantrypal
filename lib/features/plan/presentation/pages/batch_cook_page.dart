import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/shopping_cubit.dart';
import 'package:pantrypal/features/plan/domain/meal_planner.dart';
import 'package:pantrypal/features/plan/presentation/plan_cubit.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Cook once from what you have: choose people, days and meals a day, and the
/// plan updates instantly — which dishes, how many portions, what goes in the
/// fridge and what goes straight into the freezer.
class BatchCookPage extends StatefulWidget {
  const BatchCookPage({super.key});

  @override
  State<BatchCookPage> createState() => _BatchCookPageState();
}

class _BatchCookPageState extends State<BatchCookPage> {
  late int _people;
  int _days = 4;
  int _mealsPerDay = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _people = context.read<PlanCubit>().state.household;
  }

  Future<void> _start(BatchPlan plan) async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    await context.read<PlanCubit>().saveBatch(plan);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.primary,
      content: Text('Batch cook added to today · tap "Cooked it" when it\'s done'),
    ));
  }

  Future<void> _addMissing(List<String> names) async {
    final added = await context.read<ShoppingCubit>().addNames(names);
    Analytics.track('plan_missing_added', {'count': added, 'batch': true});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added == 0 ? 'Already on your shopping list' : 'Added $added to your shopping list'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;

    final pantryState = context.watch<PantryBloc>().state;
    final recipeState = context.watch<RecipeBloc>().state;
    final pantry = pantryState is PantryLoaded ? pantryState.allItems : <PantryItem>[];
    final recipes = recipeState is RecipeLoaded ? recipeState.all : <Recipe>[];

    // Instant: runs on the phone, no network.
    final plan = BatchPlanner.plan(
      recipes: recipes,
      pantry: pantry,
      people: _people,
      days: _days,
      mealsPerDay: _mealsPerDay,
    );
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
      appBar: AppBar(title: const Text('Batch cook')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text('Cook once from what you have, eat all week.', style: TextStyle(fontSize: 14, color: muted)),
          const SizedBox(height: 14),

          // ── Controls ──
          _Panel(
            isDark: isDark,
            child: Column(
              children: [
                _CountRow(
                  label: 'People',
                  value: _people,
                  min: 1,
                  max: 8,
                  onChanged: (v) => setState(() => _people = v),
                ),
                const Divider(height: 20),
                _ChoiceRow(
                  label: 'Days',
                  options: const [2, 3, 4, 5, 6, 7],
                  value: _days,
                  format: (v) => '$v',
                  onChanged: (v) => setState(() => _days = v),
                ),
                const Divider(height: 20),
                _ChoiceRow(
                  label: 'Meals a day',
                  options: const [1, 2],
                  value: _mealsPerDay,
                  format: (v) => v == 1 ? 'Dinner' : 'Lunch + dinner',
                  onChanged: (v) => setState(() => _mealsPerDay = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Result ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: plan.isEmpty
                ? _Panel(
                    key: const ValueKey('empty'),
                    isDark: isDark,
                    child: Text(
                      'Your pantry doesn\'t cover a batch dish yet. Add a few more foods — a protein, a vegetable and a staple like rice or pasta.',
                      style: TextStyle(fontSize: 14, color: muted, height: 1.5),
                    ),
                  )
                : Column(
                    key: ValueKey('${plan.dishes.length}-${plan.totalPortions}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cook ${plan.dishes.length} dish${plan.dishes.length == 1 ? '' : 'es'} today → ${plan.totalPortions} portions',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.freezerPortions > 0
                            ? '${plan.totalPortions - plan.freezerPortions} for the fridge · ${plan.freezerPortions} straight into the freezer'
                            : 'All ${plan.totalPortions} keep in the fridge',
                        style: TextStyle(fontSize: 14, color: muted),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < plan.dishes.length; i++) _DishCard(dish: plan.dishes[i], index: i, isDark: isDark),
                      const SizedBox(height: 8),
                      Text('Your week', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
                      const SizedBox(height: 8),
                      _Panel(
                        isDark: isDark,
                        child: Column(
                          children: [
                            for (var d = 0; d < plan.days; d++)
                              _DayRow(
                                label: d == 0
                                    ? 'Today'
                                    : _weekdays[DateTime(today.year, today.month, today.day + d).weekday - 1],
                                slots: plan.schedule.where((s) => s.day == d).toList(),
                                dishes: plan.dishes,
                                isDark: isDark,
                              ),
                          ],
                        ),
                      ),
                      if (plan.toBuy.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Panel(
                          isDark: isDark,
                          child: Row(
                            children: [
                              const Text('🛒', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('To buy: ${plan.toBuy.join(', ')}',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink)),
                              ),
                              TextButton(onPressed: () => _addMissing(plan.toBuy), child: const Text('Add to list')),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: plan.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _start(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Start batch cook', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _Panel({super.key, required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: child,
      );
}

class _CountRow extends StatelessWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const _CountRow({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          IconButton.outlined(
            tooltip: 'Fewer',
            onPressed: value > min
                ? () {
                    HapticFeedback.selectionClick();
                    onChanged(value - 1);
                  }
                : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 40,
            child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          IconButton.outlined(
            tooltip: 'More',
            onPressed: value < max
                ? () {
                    HapticFeedback.selectionClick();
                    onChanged(value + 1);
                  }
                : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      );
}

class _ChoiceRow extends StatelessWidget {
  final String label;
  final List<int> options;
  final int value;
  final String Function(int) format;
  final ValueChanged<int> onChanged;
  const _ChoiceRow({
    required this.label,
    required this.options,
    required this.value,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(format(o)),
                  selected: o == value,
                  selectedColor: AppColors.primarySurface,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    onChanged(o);
                  },
                ),
            ],
          ),
        ],
      );
}

const _dishColors = [AppColors.primary, Color(0xFFEF6C00), Color(0xFF1565C0)];

class _DishCard extends StatelessWidget {
  final BatchDish dish;
  final int index;
  final bool isDark;
  const _DishCard({required this.dish, required this.index, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final o = dish.option;
    final color = _dishColors[index % _dishColors.length];
    final scale = dish.scale;
    final scaleText = scale == scale.roundToDouble() ? '×${scale.toInt()}' : '×${scale.toStringAsFixed(1)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(o.recipe.name,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkInk : AppColors.ink)),
              ),
              Text('${dish.portions} portions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              'Make the recipe $scaleText',
              o.recipe.timeLabel,
              if (dish.freezerPortions > 0) '${dish.freezerPortions} to freeze',
            ].join(' · '),
            style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in o.usesSoon) _Tag(p.name, AppColors.expiringSoonSurface, AppColors.expiringSoon, Icons.timer_outlined),
              for (final i in o.real.where((i) => i.have && !o.usesSoon.any((s) => s.id == i.item?.id)))
                _Tag(i.name, AppColors.primarySurface, AppColors.primary, Icons.check),
              for (final m in o.missingIngredients) _Tag(m.name, AppColors.border, AppColors.inkMuted, Icons.add_shopping_cart),
            ],
          ),
          if (scale > 1.5 && o.usedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Check you have enough for $scaleText the recipe.',
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontStyle: FontStyle.italic)),
          ],
        ],
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      );
}

class _DayRow extends StatelessWidget {
  final String label;
  final List<BatchSlot> slots;
  final List<BatchDish> dishes;
  final bool isDark;
  const _DayRow({required this.label, required this.slots, required this.dishes, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final frozen = slots.any((s) => s.fromFreezer);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.inkMuted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in slots)
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: _dishColors[s.dish % _dishColors.length], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(dishes[s.dish].option.recipe.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkInk : AppColors.ink)),
                      ),
                      if (s.fromFreezer) const Text('  🧊', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                if (frozen)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('From the freezer — move it to the fridge the night before',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF1565C0))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
