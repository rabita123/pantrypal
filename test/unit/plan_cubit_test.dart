import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/plan/data/plan_repository.dart';
import 'package:pantrypal/features/plan/domain/meal_planner.dart';
import 'package:pantrypal/features/plan/presentation/plan_cubit.dart';

import '../support/fixtures.dart';
import '../support/plugin_stubs.dart';
import '../support/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlanCubit cubit;
  final db = DatabaseHelper.instance;

  setUpAll(() async {
    await initTestDatabase('plan_cubit');
    stubNotificationPlugin();
    stubHomeWidgetPlugin();
  });

  setUp(() async {
    stubSharedPreferences();
    await db.clearAllData();
    cubit = PlanCubit(PlanRepository(), PantryRepository());
    await cubit.load();
  });

  tearDown(() => cubit.close());

  List<PlannedMealDraft> drafts(List<PantryItem> pantry, int days) => MealPlanner.plan(
        recipes: [
          recipe(id: 'r1', name: 'Chicken Rice', servings: 4, ingredients: [ingredient('Chicken'), ingredient('Rice')]),
          recipe(id: 'r2', name: 'Pasta Bake', servings: 4, ingredients: [ingredient('Pasta'), ingredient('Cheese')]),
        ],
        pantry: pantry,
        days: days,
      );

  test('the schema has the plan and portion tables', () async {
    final raw = await db.database;
    final tables = (await raw.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
        .map((r) => r['name'])
        .toSet();
    expect(tables, containsAll([AppConstants.mealsTable, AppConstants.portionsTable]));
  });

  test('household size defaults to 2 and is remembered', () async {
    expect(cubit.state.household, 2);
    await cubit.setHousehold(4);
    expect(cubit.state.household, 4);
  });

  test('saving a plan stores one meal per day at the household size', () async {
    final pantry = [item(name: 'Chicken', category: FoodCategory.meat, daysFromNow: 2), item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 300),
      item(name: 'Pasta', category: FoodCategory.grains, daysFromNow: 300), item(name: 'Cheese', daysFromNow: 20)];
    await cubit.setHousehold(3);
    await cubit.savePlan(drafts(pantry, 2));
    expect(cubit.state.meals.map((m) => m.recipeName), ['Chicken Rice', 'Pasta Bake']);
    expect(cubit.state.meals.every((m) => m.servings == 3 && m.status == MealStatus.planned), isTrue);
  });

  test('re-planning replaces uncooked meals but keeps cooked ones and batch cooks', () async {
    final pantry = [item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 300), item(name: 'Chicken', category: FoodCategory.meat, daysFromNow: 3)];
    await cubit.savePlan(drafts(pantry, 1));
    final first = cubit.state.meals.single;
    await cubit.cooked(meal: first, portionsMade: 2, eatingNow: 2, freeze: 0, used: const []);

    await cubit.saveBatch(BatchPlanner.plan(
      recipes: [recipe(id: 'b', name: 'Batch Rice', servings: 4, ingredients: [ingredient('Rice')])],
      pantry: pantry, people: 2, days: 2, mealsPerDay: 1,
    ));
    await cubit.savePlan(drafts(pantry, 1));

    final names = cubit.state.meals.map((m) => '${m.recipeName}:${m.status.name}:${m.isBatch}').toList();
    expect(names, contains('Chicken Rice:cooked:false'));
    expect(names, contains('Batch Rice:planned:true'));
  });

  group('Cooked it', () {
    test('uses up single items, takes one from multi-packs, and ticks the meal off', () async {
      final chicken = item(name: 'Chicken', category: FoodCategory.meat, daysFromNow: 1);
      final eggs = item(name: 'Eggs', category: FoodCategory.eggs, quantity: 6);
      await db.insertItem(chicken);
      await db.insertItem(eggs);
      await cubit.savePlan(drafts([chicken, item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 300)], 1));
      final meal = cubit.state.meals.single;

      await cubit.cooked(meal: meal, portionsMade: 2, eatingNow: 2, freeze: 0, used: [chicken, eggs]);

      final active = await db.getAllActiveItems();
      expect(active.any((i) => i.id == chicken.id), isFalse, reason: 'chicken used up');
      expect(active.firstWhere((i) => i.id == eggs.id).quantity, 5, reason: 'one egg pack portion used');
      expect(cubit.state.meals.single.status, MealStatus.cooked);

      final stats = await db.getStats();
      expect(stats['consumedMonth'], 1, reason: 'used food counts as saved');
    });

    test('leftovers become fridge and freezer portions with honest eat-by dates', () async {
      await cubit.savePlan(drafts([item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 300), item(name: 'Chicken', category: FoodCategory.meat)], 1));
      final meal = cubit.state.meals.single;
      final now = DateTime(2026, 3, 9, 19);

      final created = await cubit.cooked(meal: meal, portionsMade: 8, eatingNow: 2, freeze: 4, used: const [], now: now);

      final fridge = created.firstWhere((p) => p.location == PortionLocation.fridge);
      final freezer = created.firstWhere((p) => p.location == PortionLocation.freezer);
      expect(fridge.remaining, 2);
      expect(freezer.remaining, 4);
      expect(fridge.eatBy, DateTime(2026, 3, 12, 12));
      expect(freezer.eatBy, DateTime(2026, 3, 9 + PlanCubit.freezerLifeDays, 12));
      expect(cubit.state.portionsLeft, 6);
    });

    test('freeze can never exceed what is left over', () async {
      await cubit.savePlan(drafts([item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 300), item(name: 'Chicken', category: FoodCategory.meat)], 1));
      final created = await cubit.cooked(
          meal: cubit.state.meals.single, portionsMade: 4, eatingNow: 3, freeze: 9, used: const []);
      expect(created.single.location, PortionLocation.freezer);
      expect(created.single.remaining, 1);
    });

    test('eating everything now leaves no portions', () async {
      await cubit.savePlan(drafts([item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 300), item(name: 'Chicken', category: FoodCategory.meat)], 1));
      final created = await cubit.cooked(
          meal: cubit.state.meals.single, portionsMade: 2, eatingNow: 2, freeze: 0, used: const []);
      expect(created, isEmpty);
      expect(cubit.state.portions, isEmpty);
    });
  });

  group('Portions', () {
    Future<PortionBatch> cook(int leftovers) async {
      await cubit.savePlan(drafts([item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 300), item(name: 'Chicken', category: FoodCategory.meat)], 1));
      final created = await cubit.cooked(
          meal: cubit.state.meals.single, portionsMade: leftovers + 1, eatingNow: 1, freeze: 0, used: const []);
      return created.single;
    }

    test('eating counts down and finishes the batch at zero', () async {
      final p = await cook(2);
      await cubit.eatPortion(p);
      expect(cubit.state.portions.single.remaining, 1);
      await cubit.eatPortion(cubit.state.portions.single);
      expect(cubit.state.portions, isEmpty);
    });

    test('moving to the freezer extends the eat-by date', () async {
      final p = await cook(3);
      await cubit.freezePortions(p);
      final moved = cubit.state.portions.single;
      expect(moved.location, PortionLocation.freezer);
      expect(moved.daysLeft, greaterThan(60));
    });

    test('throwing the rest away clears it', () async {
      final p = await cook(3);
      await cubit.tossPortions(p);
      expect(cubit.state.portions, isEmpty);
    });
  });

  test('a batch cook saves one meal per dish for today, with its freezer split', () async {
    final pantry = [
      item(name: 'Chicken', category: FoodCategory.meat, daysFromNow: 2),
      item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 300),
    ];
    final plan = BatchPlanner.plan(
      recipes: [recipe(id: 'c', name: 'Chicken Rice', servings: 4, ingredients: [ingredient('Chicken'), ingredient('Rice')])],
      pantry: pantry, people: 2, days: 6, mealsPerDay: 1,
    );
    await cubit.saveBatch(plan);
    final m = cubit.state.batch.single;
    expect(m.servings, 12);
    expect(m.freezePortions, 4, reason: 'days 4 and 5 for 2 people');
    final today = DateTime.now();
    expect(DateTime(m.date.year, m.date.month, m.date.day), DateTime(today.year, today.month, today.day));
  });

  moreTests();
}

void moreTests() {
  group('Month stats and adding meals', () {
    late PlanCubit cubit;
    setUp(() async {
      stubSharedPreferences();
      await DatabaseHelper.instance.clearAllData();
      cubit = PlanCubit(PlanRepository(), PantryRepository());
      await cubit.load();
    });
    tearDown(() => cubit.close());

    test('addMeal puts a recipe on tonight at the household size', () async {
      await cubit.setHousehold(3);
      await cubit.addMeal(recipe(id: 'ai-1', name: 'Spinach Omelette'));
      final m = cubit.state.meals.single;
      expect(m.recipeName, 'Spinach Omelette');
      expect(m.servings, 3);
      final t = DateTime.now();
      expect(DateTime(m.date.year, m.date.month, m.date.day), DateTime(t.year, t.month, t.day));
    });

    test('month stats count cooked meals and leftovers eaten vs tossed', () async {
      await cubit.addMeal(recipe(id: 'a', name: 'A'));
      final created = await cubit.cooked(
          meal: cubit.state.meals.single, portionsMade: 6, eatingNow: 2, freeze: 0, used: const []);
      await cubit.eatPortion(created.single); // 1 eaten
      await cubit.eatPortion(cubit.state.portions.single); // 2 eaten
      await cubit.tossPortions(cubit.state.portions.single); // 2 tossed

      final m = cubit.state.month;
      expect(m.mealsCooked, 1);
      expect(m.portionsEaten, 2);
      expect(m.portionsTossed, 2);
    });
  });
}
