import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/plan/domain/meal_planner.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';

/// Premium: when the built-in recipes run out before the week does, ask the
/// AI for meals made from the user's own food and put them on the empty days.
class PlanFiller {
  /// Snacks, sweets and drinks are not dinner ingredients — sending them is
  /// how "tuna salad with cookie crumble" happens.
  static const _notMealFood = {FoodCategory.snacks, FoodCategory.beverages, FoodCategory.condiments};

  /// Food to build the extra meals around: what the planned meals do not use
  /// yet, soonest-expiring first; falls back to the whole pantry.
  static List<PantryItem> pickFor(List<PlannedMealDraft> draft, List<PantryItem> pantry, {int max = 8}) {
    final usable = pantry
        .where((p) => p.isActive && p.daysUntilExpiry >= 0 && !_notMealFood.contains(p.category))
        .toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    final used = {for (final d in draft) ...d.option.usedItems.map((p) => p.id)};
    final fresh = usable.where((p) => !used.contains(p.id)).toList();
    return (fresh.isNotEmpty ? fresh : usable).take(max).toList();
  }

  /// Adds AI meals after [draft] until [days] are covered or [maxCalls] runs
  /// out. Returns the full plan and the new recipes (to be saved).
  static Future<({List<PlannedMealDraft> plan, List<Recipe> added})> fill({
    required List<PlannedMealDraft> draft,
    required int days,
    required List<PantryItem> pantry,
    required DateTime start,
    required Future<List<Recipe>> Function(List<PantryItem> picked) ideas,
    Set<String> existingNames = const {},
    int maxCalls = 3,
  }) async {
    final plan = [...draft];
    final added = <Recipe>[];
    final names = {...existingNames.map((n) => n.toLowerCase()), for (final d in draft) d.option.recipe.name.toLowerCase()};
    final first = DateTime(start.year, start.month, start.day);

    for (var call = 0; call < maxCalls && plan.length < days; call++) {
      final picked = pickFor(plan, pantry);
      if (picked.isEmpty) break;
      final got = await ideas(picked);
      var progress = false;
      for (final r in got) {
        if (plan.length >= days) break;
        if (!names.add(r.name.toLowerCase())) continue; // no repeats
        final option = MealPlanner.evaluateSequence([r], pantry).single;
        plan.add(PlannedMealDraft(option, DateTime(first.year, first.month, first.day + plan.length)));
        added.add(r);
        progress = true;
      }
      if (!progress) break;
    }
    return (plan: plan, added: added);
  }
}
