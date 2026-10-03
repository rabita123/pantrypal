import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/plan/domain/meal_planner.dart';

import '../support/fixtures.dart';

PantryItem veg(String n, int days, {double qty = 1}) =>
    item(name: n, category: FoodCategory.vegetables, daysFromNow: days, quantity: qty);
PantryItem meat(String n, int days) => item(name: n, category: FoodCategory.meat, daysFromNow: days);
PantryItem dry(String n) => item(name: n, category: FoodCategory.grains, daysFromNow: 300);

void main() {
  group('MealPlanner.plan', () {
    test('plans only meals the pantry mostly covers — never padding', () {
      final recipes = [
        recipe(id: 'a', name: 'Chicken Rice', ingredients: [ingredient('Chicken'), ingredient('Rice')]),
        recipe(id: 'b', name: 'Lobster Thermidor', ingredients: [ingredient('Lobster'), ingredient('Cream'), ingredient('Brandy')]),
      ];
      final plan = MealPlanner.plan(recipes: recipes, pantry: [meat('Chicken', 2), dry('Rice')], days: 7);
      expect(plan.map((p) => p.option.recipe.name), ['Chicken Rice']);
    });

    test('uses food that expires first, first', () {
      final recipes = [
        recipe(id: 'a', name: 'Spinach Omelette', ingredients: [ingredient('Spinach'), ingredient('Eggs')]),
        recipe(id: 'b', name: 'Carrot Soup', ingredients: [ingredient('Carrots'), ingredient('Onion')]),
      ];
      final pantry = [
        veg('Spinach', 1),
        item(name: 'Eggs', category: FoodCategory.eggs, daysFromNow: 14, quantity: 6),
        veg('Carrots', 20),
        veg('Onion', 25),
      ];
      final plan = MealPlanner.plan(recipes: recipes, pantry: pantry, days: 2);
      expect(plan.first.option.recipe.name, 'Spinach Omelette');
      expect(plan.first.option.usesSoon.single.name, 'Spinach');
    });

    test('two meals never both count on the same perishable item', () {
      final recipes = [
        recipe(id: 'a', name: 'Chicken Salad', ingredients: [ingredient('Chicken'), ingredient('Lettuce')]),
        recipe(id: 'b', name: 'Chicken Wrap', ingredients: [ingredient('Chicken'), ingredient('Tortillas')]),
      ];
      final pantry = [meat('Chicken', 2), veg('Lettuce', 3), dry('Tortillas')];
      final plan = MealPlanner.plan(recipes: recipes, pantry: pantry, days: 2);
      // After the first meal uses the chicken, the second is only half covered
      // and still allowed — but it must now show chicken as missing.
      if (plan.length == 2) {
        expect(plan[1].option.missingNames, contains('Chicken'));
      }
      expect(plan.first.option.missingNames, isEmpty);
    });

    test('long-lasting basics can serve several meals', () {
      final recipes = [
        recipe(id: 'a', name: 'Fried Rice', ingredients: [ingredient('Rice'), ingredient('Eggs')]),
        recipe(id: 'b', name: 'Rice Bowl', ingredients: [ingredient('Rice'), ingredient('Spinach')]),
      ];
      final pantry = [
        dry('Rice'),
        item(name: 'Eggs', category: FoodCategory.eggs, daysFromNow: 10),
        veg('Spinach', 3),
      ];
      final plan = MealPlanner.plan(recipes: recipes, pantry: pantry, days: 2);
      expect(plan, hasLength(2));
      expect(plan.every((p) => p.option.noShopping), isTrue);
    });

    test('a recipe is never planned twice', () {
      final recipes = [recipe(id: 'a', name: 'Rice Bowl', ingredients: [ingredient('Rice')])];
      final plan = MealPlanner.plan(recipes: recipes, pantry: [dry('Rice')], days: 5);
      expect(plan, hasLength(1));
    });

    test('meals land on consecutive days from today', () {
      final recipes = [
        recipe(id: 'a', ingredients: [ingredient('Rice')]),
        recipe(id: 'b', ingredients: [ingredient('Pasta')]),
      ];
      final start = DateTime(2026, 3, 9);
      final plan = MealPlanner.plan(
          recipes: recipes, pantry: [dry('Rice'), dry('Pasta')], days: 2, start: start);
      expect(plan.map((p) => p.date), [DateTime(2026, 3, 9), DateTime(2026, 3, 10)]);
    });

    test('expired and used-up items are ignored', () {
      final recipes = [recipe(id: 'a', ingredients: [ingredient('Milk')])];
      expect(MealPlanner.plan(recipes: recipes, pantry: [item(name: 'Milk', daysFromNow: -1)], days: 3), isEmpty);
      expect(MealPlanner.plan(recipes: recipes, pantry: [item(name: 'Milk', isConsumed: true)], days: 3), isEmpty);
    });

    test('staples are assumed, never listed as missing', () {
      final recipes = [
        recipe(id: 'a', ingredients: [ingredient('Eggs'), ingredient('Salt'), ingredient('Olive Oil')]),
      ];
      final plan = MealPlanner.plan(
          recipes: recipes, pantry: [item(name: 'Eggs', category: FoodCategory.eggs)], days: 1);
      expect(plan.single.option.noShopping, isTrue);
    });

    test('excluded recipes are skipped', () {
      final recipes = [recipe(id: 'a', ingredients: [ingredient('Rice')])];
      expect(MealPlanner.plan(recipes: recipes, pantry: [dry('Rice')], days: 1, exclude: {'a'}), isEmpty);
    });
  });

  group('MealPlanner.evaluateSequence', () {
    test('later meals see what earlier meals used', () {
      final a = recipe(id: 'a', ingredients: [ingredient('Chicken'), ingredient('Rice')]);
      final b = recipe(id: 'b', ingredients: [ingredient('Chicken'), ingredient('Pasta')]);
      final seq = MealPlanner.evaluateSequence([a, b], [meat('Chicken', 2), dry('Rice'), dry('Pasta')]);
      expect(seq[0].missingNames, isEmpty);
      expect(seq[1].missingNames, ['Chicken']);
    });

    test('reflects the pantry right now (an item used since planning is now missing)', () {
      final a = recipe(id: 'a', ingredients: [ingredient('Chicken'), ingredient('Rice')]);
      final seq = MealPlanner.evaluateSequence([a], [dry('Rice')]);
      expect(seq.single.missingNames, ['Chicken']);
    });
  });

  group('MealPlanner.alternative', () {
    test('offers a different recipe, honouring what the rest of the plan uses', () {
      final keep = recipe(id: 'keep', ingredients: [ingredient('Chicken'), ingredient('Rice')]);
      final swapOut = recipe(id: 'out', ingredients: [ingredient('Pasta')]);
      final alt = recipe(id: 'alt', ingredients: [ingredient('Spinach'), ingredient('Eggs')]);
      final greedy = recipe(id: 'greedy', ingredients: [ingredient('Chicken'), ingredient('Lettuce')]);
      final pantry = [
        meat('Chicken', 1),
        dry('Rice'),
        dry('Pasta'),
        veg('Spinach', 2),
        item(name: 'Eggs', category: FoodCategory.eggs),
        veg('Lettuce', 4),
      ];
      final best = MealPlanner.alternative(
        recipes: [keep, swapOut, alt, greedy],
        pantry: pantry,
        otherMeals: [keep],
        exclude: {'keep', 'out'},
      );
      expect(best!.recipe.id, 'alt', reason: 'the chicken is already spoken for');
    });
  });

  group('MealPlanner.insight', () {
    test('counts what the plan does for the user', () {
      final a = recipe(id: 'a', ingredients: [ingredient('Spinach'), ingredient('Rice')]);
      final b = recipe(id: 'b', ingredients: [ingredient('Tomatoes'), ingredient('Basil'), ingredient('Pasta')]);
      final pantry = [veg('Spinach', 1), dry('Rice'), veg('Tomatoes', 2), dry('Pasta'), veg('Kale', 2)];
      final meals = MealPlanner.evaluateSequence([a, b], pantry);
      final ins = MealPlanner.insight(meals: meals, pantry: pantry, mealsPossible: 4);

      expect(ins.mealsPossible, 4);
      expect(ins.needUsingSoon, 3, reason: 'spinach, tomatoes, kale');
      expect(ins.usedSoonByPlan, 2, reason: 'kale is not used by this plan');
      expect(ins.noShoppingMeals, 1);
      expect(ins.shoppingMeals, 1);
      expect(ins.toBuy, ['Basil']);
    });
  });

  group('BatchPlanner', () {
    final recipes = [
      recipe(id: 'curry', name: 'Chicken Curry', servings: 4,
          ingredients: [ingredient('Chicken'), ingredient('Rice'), ingredient('Onion')]),
      recipe(id: 'chili', name: 'Bean Chili', servings: 4,
          ingredients: [ingredient('Beans'), ingredient('Tomatoes'), ingredient('Onion')]),
      recipe(id: 'pasta', name: 'Pasta Bake', servings: 4,
          ingredients: [ingredient('Pasta'), ingredient('Cheese')]),
    ];
    final pantry = [
      meat('Chicken', 2), dry('Rice'), veg('Onion', 20, qty: 3), dry('Beans'),
      veg('Tomatoes', 3), dry('Pasta'), item(name: 'Cheese', daysFromNow: 20),
    ];

    test('fewer dishes for small batches, more variety for big ones', () {
      expect(BatchPlanner.dishCountFor(2, 4, 1), 1); // 8 portions
      expect(BatchPlanner.dishCountFor(2, 5, 1), 2); // 10
      expect(BatchPlanner.dishCountFor(4, 5, 2), 3); // 40
      expect(BatchPlanner.dishCountFor(6, 1, 1), 1); // only one meal slot
    });

    test('portions add up exactly to people × days × meals', () {
      final p = BatchPlanner.plan(recipes: recipes, pantry: pantry, people: 2, days: 5, mealsPerDay: 2);
      expect(p.totalPortions, 20);
      expect(p.dishes.fold<int>(0, (s, d) => s + d.portions), 20);
      for (final d in p.dishes) {
        expect(d.fridgePortions + d.freezerPortions, d.portions);
      }
    });

    test('anything eaten after day 3 is frozen on cook day', () {
      final p = BatchPlanner.plan(recipes: recipes, pantry: pantry, people: 2, days: 6, mealsPerDay: 1);
      final late = p.schedule.where((s) => s.day > BatchPlanner.fridgeDays);
      expect(late, isNotEmpty);
      expect(late.every((s) => s.fromFreezer), isTrue);
      expect(p.schedule.where((s) => s.day <= 3).every((s) => !s.fromFreezer), isTrue);
      expect(p.freezerPortions, 2 * 2, reason: 'days 4 and 5, two people');
    });

    test('consecutive meals alternate dishes when there is more than one', () {
      final p = BatchPlanner.plan(recipes: recipes, pantry: pantry, people: 2, days: 5, mealsPerDay: 1);
      expect(p.dishes.length, 2);
      final order = p.schedule.map((s) => s.dish).toList();
      for (var i = 1; i < order.length; i++) {
        expect(order[i], isNot(order[i - 1]));
      }
    });

    test('scales the recipe to the portions needed', () {
      final p = BatchPlanner.plan(recipes: recipes, pantry: pantry, people: 2, days: 4, mealsPerDay: 1);
      expect(p.dishes.single.portions, 8);
      expect(p.dishes.single.scale, 2.0, reason: 'recipe serves 4');
    });

    test('an empty pantry gives an empty plan, not a made-up one', () {
      final p = BatchPlanner.plan(recipes: recipes, pantry: const [], people: 2, days: 4, mealsPerDay: 1);
      expect(p.isEmpty, isTrue);
    });
  });

  batchFriendlyTests();
}

void batchFriendlyTests() {
  group('Batch-friendly dishes', () {
    test('quick dishes that do not keep are never batch cooked', () {
      final plan = BatchPlanner.plan(
        recipes: [
          recipe(id: 'o', name: 'Omelette', servings: 2, ingredients: [ingredient('Eggs'), ingredient('Cheese')]),
          recipe(id: 'c', name: 'Chicken Curry', servings: 4, ingredients: [ingredient('Chicken'), ingredient('Rice')]),
        ],
        pantry: [
          item(name: 'Eggs', category: FoodCategory.eggs, quantity: 12),
          item(name: 'Cheese', daysFromNow: 20),
          meat('Chicken', 2),
          dry('Rice'),
        ],
        people: 2,
        days: 4,
        mealsPerDay: 1,
      );
      expect(plan.dishes.map((d) => d.option.recipe.name), ['Chicken Curry']);
    });

    test('names that keep well pass, ones that do not are filtered', () {
      expect(BatchPlanner.isBatchFriendly(recipe(name: 'Vegetable Soup')), isTrue);
      expect(BatchPlanner.isBatchFriendly(recipe(name: 'Spaghetti Bolognese')), isTrue);
      expect(BatchPlanner.isBatchFriendly(recipe(name: 'Scrambled Eggs')), isFalse);
      expect(BatchPlanner.isBatchFriendly(recipe(name: 'Greek Salad')), isFalse);
      expect(BatchPlanner.isBatchFriendly(recipe(name: 'Grilled Cheese Sandwich')), isFalse);
    });
  });
}
