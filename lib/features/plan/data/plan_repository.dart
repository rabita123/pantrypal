import 'package:equatable/equatable.dart';
import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MealStatus { planned, cooked, skipped }

enum PortionLocation { fridge, freezer }

/// A meal on a day. Only the recipe and day are stored: what the user has or
/// is missing is always worked out from the live pantry, so it never goes stale.
class PlannedMeal extends Equatable {
  final String id;
  final String recipeId;
  final String recipeName;
  final DateTime date;
  final int servings;
  final MealStatus status;

  /// Set when the meal is part of a batch cook.
  final String? batchId;

  /// For batch dishes: how many portions are meant for the freezer.
  final int freezePortions;

  const PlannedMeal({
    required this.id,
    required this.recipeId,
    required this.recipeName,
    required this.date,
    required this.servings,
    this.status = MealStatus.planned,
    this.batchId,
    this.freezePortions = 0,
  });

  bool get isBatch => batchId != null;

  PlannedMeal copyWith({MealStatus? status, String? recipeId, String? recipeName, int? servings}) => PlannedMeal(
        id: id,
        recipeId: recipeId ?? this.recipeId,
        recipeName: recipeName ?? this.recipeName,
        date: date,
        servings: servings ?? this.servings,
        status: status ?? this.status,
        batchId: batchId,
        freezePortions: freezePortions,
      );

  @override
  List<Object?> get props => [id, recipeId, date, servings, status, batchId, freezePortions];
}

/// Cooked food waiting to be eaten: one row per dish and storage place.
class PortionBatch extends Equatable {
  final String id;
  final String? mealId;
  final String recipeName;
  final int total;
  final int remaining;
  final PortionLocation location;
  final DateTime cookedAt;
  final DateTime eatBy;

  const PortionBatch({
    required this.id,
    required this.recipeName,
    required this.total,
    required this.remaining,
    required this.location,
    required this.cookedAt,
    required this.eatBy,
    this.mealId,
  });

  /// Calendar days until it should be eaten (0 = today, negative = overdue).
  int get daysLeft {
    final n = DateTime.now();
    return DateTime.utc(eatBy.year, eatBy.month, eatBy.day)
        .difference(DateTime.utc(n.year, n.month, n.day))
        .inDays;
  }

  @override
  List<Object?> get props => [id, remaining, location, eatBy];
}

/// This month's cooking, for the insights card.
class PlanMonthStats extends Equatable {
  final int mealsCooked;
  final int portionsEaten;
  final int portionsTossed;
  const PlanMonthStats({this.mealsCooked = 0, this.portionsEaten = 0, this.portionsTossed = 0});

  @override
  List<Object?> get props => [mealsCooked, portionsEaten, portionsTossed];
}

class PlanRepository {
  final _db = DatabaseHelper.instance;
  static const _prefHousehold = 'household_size';

  static int _day(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

  // ── Household ─────────────────────────────────────────────────────────────

  Future<int> householdSize() async =>
      (await SharedPreferences.getInstance()).getInt(_prefHousehold) ?? 2;

  Future<void> setHouseholdSize(int n) async =>
      (await SharedPreferences.getInstance()).setInt(_prefHousehold, n.clamp(1, 12));

  // ── Meals ─────────────────────────────────────────────────────────────────

  /// Meals from today on, plus anything cooked today, oldest first.
  Future<List<PlannedMeal>> upcomingMeals({DateTime? now}) async {
    final db = await _db.database;
    final rows = await db.query(
      AppConstants.mealsTable,
      where: 'date >= ? AND status != ?',
      whereArgs: [_day(now ?? DateTime.now()), MealStatus.skipped.name],
      orderBy: 'date ASC, created_at ASC',
    );
    return rows.map(_toMeal).toList();
  }

  Future<void> insertMeals(List<PlannedMeal> meals) async {
    final db = await _db.database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < meals.length; i++) {
      batch.insert(AppConstants.mealsTable, _fromMeal(meals[i], now + i));
    }
    await batch.commit(noResult: true);
  }

  /// Removes not-yet-cooked, non-batch meals from today on — used before a
  /// fresh plan is saved. Cooked meals and batch cooks are left alone.
  Future<void> clearPlannedFrom(DateTime from) async {
    final db = await _db.database;
    await db.delete(
      AppConstants.mealsTable,
      where: 'date >= ? AND status = ? AND batch_id IS NULL',
      whereArgs: [_day(from), MealStatus.planned.name],
    );
  }

  Future<void> updateMeal(PlannedMeal m) async {
    final db = await _db.database;
    await db.update(
      AppConstants.mealsTable,
      {
        'recipe_id': m.recipeId,
        'recipe_name': m.recipeName,
        'servings': m.servings,
        'status': m.status.name,
      },
      where: 'id = ?',
      whereArgs: [m.id],
    );
  }

  Future<void> deleteMeal(String id) async {
    final db = await _db.database;
    await db.delete(AppConstants.mealsTable, where: 'id = ?', whereArgs: [id]);
  }

  // ── Portions ──────────────────────────────────────────────────────────────

  Future<List<PortionBatch>> activePortions() async {
    final db = await _db.database;
    final rows = await db.query(
      AppConstants.portionsTable,
      where: 'remaining > 0',
      orderBy: 'eat_by ASC',
    );
    return rows.map(_toPortion).toList();
  }

  Future<void> insertPortion(PortionBatch p) async {
    final db = await _db.database;
    await db.insert(AppConstants.portionsTable, {
      'id': p.id,
      'meal_id': p.mealId,
      'recipe_name': p.recipeName,
      'total': p.total,
      'remaining': p.remaining,
      'location': p.location.name,
      'cooked_at': p.cookedAt.millisecondsSinceEpoch,
      'eat_by': p.eatBy.millisecondsSinceEpoch,
    });
  }

  Future<void> setRemaining(String id, int remaining) async {
    final db = await _db.database;
    await db.update(
      AppConstants.portionsTable,
      {
        'remaining': remaining < 0 ? 0 : remaining,
        if (remaining <= 0) 'finished_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> movePortions(String id, PortionLocation to, DateTime eatBy) async {
    final db = await _db.database;
    await db.update(
      AppConstants.portionsTable,
      {'location': to.name, 'eat_by': eatBy.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> tossPortions(String id) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE ${AppConstants.portionsTable} SET tossed = tossed + remaining, remaining = 0, finished_at = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  Future<PlanMonthStats> monthStats({DateTime? now}) async {
    final db = await _db.database;
    final t = now ?? DateTime.now();
    final start = DateTime(t.year, t.month).millisecondsSinceEpoch;
    final cooked = (await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${AppConstants.mealsTable} WHERE status = ? AND date >= ?',
      [MealStatus.cooked.name, start],
    )).first['n'] as int? ?? 0;
    final p = (await db.rawQuery(
      'SELECT COALESCE(SUM(total - remaining - tossed), 0) AS eaten, COALESCE(SUM(tossed), 0) AS tossed '
      'FROM ${AppConstants.portionsTable} WHERE cooked_at >= ?',
      [start],
    )).first;
    return PlanMonthStats(
      mealsCooked: cooked,
      portionsEaten: (p['eaten'] as num?)?.toInt() ?? 0,
      portionsTossed: (p['tossed'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  PlannedMeal _toMeal(Map<String, dynamic> r) => PlannedMeal(
        id: r['id'] as String,
        recipeId: r['recipe_id'] as String,
        recipeName: r['recipe_name'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(r['date'] as int),
        servings: r['servings'] as int,
        status: MealStatus.values.firstWhere((s) => s.name == r['status'], orElse: () => MealStatus.planned),
        batchId: r['batch_id'] as String?,
        freezePortions: (r['freeze_portions'] as int?) ?? 0,
      );

  Map<String, dynamic> _fromMeal(PlannedMeal m, int createdAt) => {
        'id': m.id,
        'recipe_id': m.recipeId,
        'recipe_name': m.recipeName,
        'date': _day(m.date),
        'servings': m.servings,
        'status': m.status.name,
        'batch_id': m.batchId,
        'freeze_portions': m.freezePortions,
        'created_at': createdAt,
      };

  PortionBatch _toPortion(Map<String, dynamic> r) => PortionBatch(
        id: r['id'] as String,
        mealId: r['meal_id'] as String?,
        recipeName: r['recipe_name'] as String,
        total: r['total'] as int,
        remaining: r['remaining'] as int,
        location: r['location'] == 'freezer' ? PortionLocation.freezer : PortionLocation.fridge,
        cookedAt: DateTime.fromMillisecondsSinceEpoch(r['cooked_at'] as int),
        eatBy: DateTime.fromMillisecondsSinceEpoch(r['eat_by'] as int),
      );
}
