import 'dart:math' as math;

import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/domain/services/cook_tonight_service.dart';

/// One ingredient of a planned meal, resolved against the pantry.
class PlanIngredient {
  final RecipeIngredient ingredient;

  /// The pantry item that covers it, or null when it has to be bought.
  final PantryItem? item;

  /// Salt, oil, water… assumed to be in every kitchen.
  final bool staple;

  const PlanIngredient(this.ingredient, {this.item, this.staple = false});

  String get name => ingredient.name;
  bool get have => staple || item != null;
  bool get missing => !have;

  /// Covered by something that expires within 3 days.
  bool get useSoon => item != null && item!.daysUntilExpiry <= 3;
}

/// A recipe evaluated against what is (still) available.
class MealOption {
  final Recipe recipe;
  final List<PlanIngredient> ingredients;
  final double score;

  const MealOption(this.recipe, this.ingredients, this.score);

  List<PlanIngredient> get real => ingredients.where((i) => !i.staple).toList();
  List<PlanIngredient> get missingIngredients => ingredients.where((i) => i.missing).toList();
  List<String> get missingNames => missingIngredients.map((i) => i.name).toList();
  int get missingCount => missingIngredients.length;
  bool get noShopping => missingCount == 0;

  /// Distinct pantry items this meal uses.
  List<PantryItem> get usedItems {
    final seen = <String>{};
    return [
      for (final i in ingredients)
        if (i.item != null && seen.add(i.item!.id)) i.item!,
    ];
  }

  /// Pantry items used here that are running out of time.
  List<PantryItem> get usesSoon => usedItems.where((p) => p.daysUntilExpiry <= 3).toList();
}

/// A meal placed on a day.
class PlannedMealDraft {
  final MealOption option;
  final DateTime date;
  const PlannedMealDraft(this.option, this.date);
}

/// The numbers that make the plan about YOUR food.
class PlanInsight {
  /// Meals the pantry can make this week without much shopping.
  final int mealsPossible;

  /// Pantry items expiring within 3 days.
  final int needUsingSoon;

  /// How many of those the plan actually uses.
  final int usedSoonByPlan;

  final int noShoppingMeals;
  final int shoppingMeals;

  /// Distinct things to buy for the whole plan.
  final List<String> toBuy;

  const PlanInsight({
    required this.mealsPossible,
    required this.needUsingSoon,
    required this.usedSoonByPlan,
    required this.noShoppingMeals,
    required this.shoppingMeals,
    required this.toBuy,
  });
}

/// A pantry item with how many more meals it can stretch to.
class _Pool {
  final PantryItem item;
  int usesLeft;
  _Pool(this.item, this.usesLeft);
}

/// Plans meals from what the user already has.
///
/// Not a recipe generator: it walks the pantry, spends the food that expires
/// first, and only suggests a meal when the pantry covers most of it. Each
/// pantry item is "used up" by the meals that need it, so two meals never
/// both count on the same chicken.
class MealPlanner {
  /// A meal is only offered if the pantry covers at least this share of it…
  static const minCoverage = 0.5;

  /// …and it needs at most this many things bought.
  static const maxMissing = 3;

  /// Long-lasting basics (a bag of rice, a jar of sauce) can serve many meals.
  static bool isReusable(PantryItem p) => _reusable(p);

  static bool _reusable(PantryItem p) =>
      const {FoodCategory.grains, FoodCategory.condiments, FoodCategory.beverages, FoodCategory.snacks}
          .contains(p.category) ||
      p.daysUntilExpiry > 30;

  static List<_Pool> _poolFrom(List<PantryItem> pantry) => [
        for (final p in pantry)
          if (p.isActive && p.daysUntilExpiry >= 0)
            _Pool(p, _reusable(p) ? 1 << 20 : p.quantity.round().clamp(1, 3)),
      ];

  /// How urgent it is to use an item, by days left.
  static double _urgency(PantryItem p) {
    final d = p.daysUntilExpiry;
    if (d <= 1) return 3;
    if (d <= 3) return 2;
    if (d <= 7) return 1;
    return 0.3;
  }

  static MealOption _evaluate(Recipe r, List<_Pool> pool) {
    final ings = <PlanIngredient>[];
    final claimed = <String>{};
    var urgency = 0.0;
    for (final ing in r.ingredients) {
      if (CookTonightService.isStaple(ing.name)) {
        ings.add(PlanIngredient(ing, staple: true));
        continue;
      }
      _Pool? hit;
      for (final p in pool) {
        if (p.usesLeft <= 0) continue;
        if (!CookTonightService.namesMatch(ing.name, p.item.name)) continue;
        // Prefer the item that expires first.
        if (hit == null || p.item.expiryDate.isBefore(hit.item.expiryDate)) hit = p;
      }
      if (hit != null && claimed.add(hit.item.id)) urgency += _urgency(hit.item);
      ings.add(PlanIngredient(ing, item: hit?.item));
    }
    final real = ings.where((i) => !i.staple).toList();
    final have = real.where((i) => i.have).length;
    final missing = real.length - have;
    final coverage = real.isEmpty ? 0.0 : have / real.length;
    final score = urgency + coverage * 4 - missing * 1.2 + (missing == 0 ? 1.5 : 0);
    return MealOption(r, ings, score);
  }

  static bool _acceptable(MealOption o) {
    final real = o.real;
    if (real.isEmpty) return false;
    final have = real.where((i) => i.have).length;
    return have >= 1 && o.missingCount <= maxMissing && have / real.length >= minCoverage;
  }

  static void _consume(MealOption o, List<_Pool> pool) {
    for (final used in o.usedItems) {
      for (final p in pool) {
        if (p.item.id == used.id) p.usesLeft--;
      }
    }
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Builds up to [days] dinners, one per day from [start], spending the most
  /// urgent food first. Fewer meals come back when the pantry runs dry —
  /// nothing is padded with meals the user cannot make.
  static List<PlannedMealDraft> plan({
    required List<Recipe> recipes,
    required List<PantryItem> pantry,
    required int days,
    DateTime? start,
    Set<String> exclude = const {},
  }) {
    final pool = _poolFrom(pantry);
    final first = _day(start ?? DateTime.now());
    final used = <String>{...exclude};
    final out = <PlannedMealDraft>[];

    for (var d = 0; d < days; d++) {
      MealOption? best;
      for (final r in recipes) {
        if (used.contains(r.id)) continue;
        final o = _evaluate(r, pool);
        if (!_acceptable(o)) continue;
        if (best == null || o.score > best.score) best = o;
      }
      if (best == null) break;
      used.add(best.recipe.id);
      _consume(best, pool);
      out.add(PlannedMealDraft(best, DateTime(first.year, first.month, first.day + d)));
    }
    return out;
  }

  /// Re-checks an existing plan against today's pantry, in order, so meals
  /// later in the week see what earlier meals have used up.
  static List<MealOption> evaluateSequence(List<Recipe> ordered, List<PantryItem> pantry) {
    final pool = _poolFrom(pantry);
    final out = <MealOption>[];
    for (final r in ordered) {
      final o = _evaluate(r, pool);
      _consume(o, pool);
      out.add(o);
    }
    return out;
  }

  /// The best replacement for one meal, given the rest of the plan.
  static MealOption? alternative({
    required List<Recipe> recipes,
    required List<PantryItem> pantry,
    required List<Recipe> otherMeals,
    required Set<String> exclude,
  }) {
    final pool = _poolFrom(pantry);
    for (final r in otherMeals) {
      _consume(_evaluate(r, pool), pool);
    }
    MealOption? best;
    for (final r in recipes) {
      if (exclude.contains(r.id)) continue;
      final o = _evaluate(r, pool);
      if (!_acceptable(o)) continue;
      if (best == null || o.score > best.score) best = o;
    }
    return best;
  }

  /// Headline numbers for a plan.
  static PlanInsight insight({
    required List<MealOption> meals,
    required List<PantryItem> pantry,
    required int mealsPossible,
  }) {
    final soon = pantry.where((p) => p.isActive && p.daysUntilExpiry >= 0 && p.daysUntilExpiry <= 3).toList();
    final usedIds = {for (final m in meals) ...m.usedItems.map((p) => p.id)};
    final toBuy = <String>[];
    final seen = <String>{};
    for (final m in meals) {
      for (final n in m.missingNames) {
        if (seen.add(n.toLowerCase())) toBuy.add(n);
      }
    }
    return PlanInsight(
      mealsPossible: mealsPossible,
      needUsingSoon: soon.length,
      usedSoonByPlan: soon.where((p) => usedIds.contains(p.id)).length,
      noShoppingMeals: meals.where((m) => m.noShopping).length,
      shoppingMeals: meals.where((m) => !m.noShopping).length,
      toBuy: toBuy,
    );
  }
}

// ── Batch cooking ─────────────────────────────────────────────────────────────

/// One dish in a batch cook.
class BatchDish {
  final MealOption option;
  final int portions;

  /// Portions to eat within 3 days (fridge) vs later (freeze straight away).
  final int fridgePortions;
  final int freezerPortions;

  const BatchDish(this.option, this.portions, this.fridgePortions, this.freezerPortions);

  /// How much to scale the recipe's quantities.
  double get scale => portions / math.max(1, option.recipe.servings);
}

/// Which dish is eaten on which day, and from where.
class BatchSlot {
  final int day; // 0 = cook day
  final int meal; // 0..mealsPerDay-1
  final int dish; // index into dishes
  final bool fromFreezer;
  const BatchSlot(this.day, this.meal, this.dish, this.fromFreezer);
}

class BatchPlan {
  final int people, days, mealsPerDay;
  final List<BatchDish> dishes;
  final List<BatchSlot> schedule;

  const BatchPlan({
    required this.people,
    required this.days,
    required this.mealsPerDay,
    required this.dishes,
    required this.schedule,
  });

  int get totalPortions => people * days * mealsPerDay;
  bool get isEmpty => dishes.isEmpty;
  int get freezerPortions => dishes.fold(0, (s, d) => s + d.freezerPortions);
  List<String> get toBuy {
    final seen = <String>{};
    return [
      for (final d in dishes)
        for (final n in d.option.missingNames)
          if (seen.add(n.toLowerCase())) n,
    ];
  }
}

/// Turns "N people × D days × M meals" into a cook-once plan from the pantry.
class BatchPlanner {
  /// Cooked food keeps about 3 days in the fridge (day 0 = cook day, so days
  /// 0–3); anything eaten later goes straight into the freezer.
  static const fridgeDays = 3;

  /// Fewer dishes is the point of batch cooking; add variety only when the
  /// batch is big enough to get boring.
  static int dishCountFor(int people, int days, int mealsPerDay) {
    final slots = days * mealsPerDay;
    final total = people * slots;
    final wanted = total <= 8 ? 1 : (total <= 16 ? 2 : 3);
    return math.min(wanted, slots);
  }

  static BatchPlan plan({
    required List<Recipe> recipes,
    required List<PantryItem> pantry,
    required int people,
    required int days,
    required int mealsPerDay,
  }) {
    final wanted = dishCountFor(people, days, mealsPerDay);
    final picks = MealPlanner.plan(recipes: recipes, pantry: pantry, days: wanted).map((d) => d.option).toList();
    if (picks.isEmpty) {
      return BatchPlan(people: people, days: days, mealsPerDay: mealsPerDay, dishes: const [], schedule: const []);
    }

    // Alternate dishes so consecutive meals differ.
    final schedule = <BatchSlot>[];
    var k = 0;
    for (var d = 0; d < days; d++) {
      for (var m = 0; m < mealsPerDay; m++) {
        schedule.add(BatchSlot(d, m, k % picks.length, d > fridgeDays));
        k++;
      }
    }

    final dishes = <BatchDish>[];
    for (var i = 0; i < picks.length; i++) {
      final mine = schedule.where((s) => s.dish == i);
      final fridge = mine.where((s) => !s.fromFreezer).length * people;
      final freezer = mine.where((s) => s.fromFreezer).length * people;
      dishes.add(BatchDish(picks[i], fridge + freezer, fridge, freezer));
    }
    return BatchPlan(people: people, days: days, mealsPerDay: mealsPerDay, dishes: dishes, schedule: schedule);
  }
}
