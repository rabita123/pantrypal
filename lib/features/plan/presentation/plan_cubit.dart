import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/plan/data/plan_repository.dart';
import 'package:pantrypal/features/plan/domain/meal_planner.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';
import 'package:uuid/uuid.dart';

class PlanState extends Equatable {
  final bool loaded;
  final List<PlannedMeal> meals;
  final List<PortionBatch> portions;
  final int household;

  const PlanState({
    this.loaded = false,
    this.meals = const [],
    this.portions = const [],
    this.household = 2,
  });

  List<PlannedMeal> get planned => meals.where((m) => m.status == MealStatus.planned).toList();
  List<PlannedMeal> get regular => meals.where((m) => !m.isBatch).toList();
  List<PlannedMeal> get batch => meals.where((m) => m.isBatch).toList();
  int get portionsLeft => portions.fold(0, (s, p) => s + p.remaining);

  @override
  List<Object?> get props => [loaded, meals, portions, household];
}

/// The plan → cook → portions loop, persisted locally.
///
/// "Cooked it" is where everything connects: the ingredients come off the
/// pantry, the meal is ticked off, and whatever is not eaten becomes portions
/// with an eat-by date in the fridge or freezer.
class PlanCubit extends Cubit<PlanState> {
  final PlanRepository _plans;
  final PantryRepository _pantry;
  static const _uuid = Uuid();

  /// Cooked food: about 3 days in the fridge, 3 months frozen.
  static const fridgeLifeDays = 3;
  static const freezerLifeDays = 90;

  PlanCubit(this._plans, this._pantry) : super(const PlanState());

  Future<void> load() async {
    final meals = await _plans.upcomingMeals();
    final portions = await _plans.activePortions();
    final household = await _plans.householdSize();
    emit(PlanState(loaded: true, meals: meals, portions: portions, household: household));
  }

  Future<void> setHousehold(int n) async {
    await _plans.setHouseholdSize(n);
    await load();
  }

  /// Replaces the upcoming (uncooked) plan with [drafts].
  Future<void> savePlan(List<PlannedMealDraft> drafts) async {
    final from = drafts.isEmpty ? DateTime.now() : drafts.first.date;
    await _plans.clearPlannedFrom(from);
    await _plans.insertMeals([
      for (final d in drafts)
        PlannedMeal(
          id: _uuid.v4(),
          recipeId: d.option.recipe.id,
          recipeName: d.option.recipe.name,
          date: d.date,
          servings: state.household,
        ),
    ]);
    Analytics.track('plan_generated', {
      'meals': drafts.length,
      'no_shop': drafts.where((d) => d.option.noShopping).length,
      'uses_soon': drafts.fold<int>(0, (s, d) => s + d.option.usesSoon.length),
    });
    await load();
  }

  Future<void> swapMeal(PlannedMeal meal, MealOption replacement) async {
    await _plans.updateMeal(meal.copyWith(recipeId: replacement.recipe.id, recipeName: replacement.recipe.name));
    Analytics.track('meal_swapped');
    await load();
  }

  Future<void> removeMeal(PlannedMeal meal) async {
    await _plans.deleteMeal(meal.id);
    await load();
  }

  /// Saves a batch cook for today: one planned meal per dish.
  Future<void> saveBatch(BatchPlan plan) async {
    final batchId = _uuid.v4();
    final today = DateTime.now();
    await _plans.insertMeals([
      for (final d in plan.dishes)
        PlannedMeal(
          id: _uuid.v4(),
          recipeId: d.option.recipe.id,
          recipeName: d.option.recipe.name,
          date: today,
          servings: d.portions,
          batchId: batchId,
          freezePortions: d.freezerPortions,
        ),
    ]);
    Analytics.track('batch_planned', {
      'people': plan.people,
      'days': plan.days,
      'meals_per_day': plan.mealsPerDay,
      'dishes': plan.dishes.length,
      'portions': plan.totalPortions,
    });
    await load();
  }

  /// The user cooked [meal]. Takes [used] off the pantry and stores the
  /// leftovers as portions. Returns the portion batches created.
  Future<List<PortionBatch>> cooked({
    required PlannedMeal meal,
    required int portionsMade,
    required int eatingNow,
    required int freeze,
    required List<PantryItem> used,
    DateTime? now,
  }) async {
    final t = now ?? DateTime.now();

    // 1. Pantry: a multi-pack loses one; a single item is used up.
    for (final item in used) {
      if (item.quantity > 1) {
        await _pantry.updateItem(item.copyWith(quantity: item.quantity - 1));
      } else {
        await _pantry.markConsumed(item.id);
      }
    }

    // 2. The meal is done.
    await _plans.updateMeal(meal.copyWith(status: MealStatus.cooked, servings: portionsMade));

    // 3. Leftovers become portions.
    final leftover = (portionsMade - eatingNow).clamp(0, 999);
    final frozen = freeze.clamp(0, leftover);
    final chilled = leftover - frozen;
    final created = <PortionBatch>[];
    DateTime day(int add) => DateTime(t.year, t.month, t.day + add, 12);
    if (chilled > 0) {
      created.add(PortionBatch(
        id: _uuid.v4(),
        mealId: meal.id,
        recipeName: meal.recipeName,
        total: chilled,
        remaining: chilled,
        location: PortionLocation.fridge,
        cookedAt: t,
        eatBy: day(fridgeLifeDays),
      ));
    }
    if (frozen > 0) {
      created.add(PortionBatch(
        id: _uuid.v4(),
        mealId: meal.id,
        recipeName: meal.recipeName,
        total: frozen,
        remaining: frozen,
        location: PortionLocation.freezer,
        cookedAt: t,
        eatBy: day(freezerLifeDays),
      ));
    }
    for (final p in created) {
      await _plans.insertPortion(p);
    }

    Analytics.track('meal_cooked', {
      'batch': meal.isBatch,
      'portions': portionsMade,
      'leftover': leftover,
      'frozen': frozen,
      'pantry_items_used': used.length,
    });
    await load();
    return created;
  }

  Future<void> eatPortion(PortionBatch p, {int count = 1}) async {
    await _plans.setRemaining(p.id, p.remaining - count);
    Analytics.track('portion_eaten', {'location': p.location});
    await load();
  }

  Future<void> freezePortions(PortionBatch p) async {
    final t = DateTime.now();
    await _plans.movePortions(p.id, PortionLocation.freezer, DateTime(t.year, t.month, t.day + freezerLifeDays, 12));
    Analytics.track('portions_frozen', {'count': p.remaining});
    await load();
  }

  Future<void> tossPortions(PortionBatch p) async {
    await _plans.tossPortions(p.id);
    Analytics.track('portions_tossed', {'count': p.remaining});
    await load();
  }
}
