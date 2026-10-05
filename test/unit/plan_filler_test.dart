import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/plan/domain/meal_planner.dart';
import 'package:pantrypal/features/plan/domain/plan_filler.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';

import '../support/fixtures.dart';

void main() {
  final pantry = [
    item(name: 'Eggs', category: FoodCategory.eggs, daysFromNow: 10),
    item(name: 'Milk', daysFromNow: 2),
    item(name: 'Bananas', category: FoodCategory.fruits, daysFromNow: 4),
  ];
  final start = DateTime(2026, 3, 9);
  final draft = MealPlanner.plan(
    recipes: [recipe(id: 'se', name: 'Scrambled Eggs', ingredients: [ingredient('Eggs'), ingredient('Milk')])],
    pantry: pantry,
    days: 7,
    start: start,
  );

  Recipe ai(String name) => recipe(id: 'ai-$name', name: name, ingredients: [ingredient('Bananas')]);

  test('fills the empty days of a short plan, on the following dates', () async {
    final res = await PlanFiller.fill(
      draft: draft,
      days: 4,
      pantry: pantry,
      start: start,
      ideas: (_) async => [ai('Banana Pancakes'), ai('Banana Bread'), ai('Smoothie')],
    );
    expect(res.plan.map((d) => d.option.recipe.name), ['Scrambled Eggs', 'Banana Pancakes', 'Banana Bread', 'Smoothie']);
    expect(res.plan.last.date, DateTime(2026, 3, 12));
    expect(res.added, hasLength(3));
  });

  test('keeps asking until the week is full, without repeating a dish', () async {
    var calls = 0;
    final res = await PlanFiller.fill(
      draft: draft,
      days: 7,
      pantry: pantry,
      start: start,
      ideas: (_) async {
        calls++;
        return [ai('A$calls'), ai('B$calls'), ai('Scrambled Eggs')];
      },
    );
    expect(res.plan, hasLength(7));
    expect(res.plan.where((d) => d.option.recipe.name == 'Scrambled Eggs'), hasLength(1));
    expect(calls, 3);
  });

  test('stops when the AI has nothing new, instead of looping', () async {
    var calls = 0;
    final res = await PlanFiller.fill(
      draft: draft,
      days: 7,
      pantry: pantry,
      start: start,
      existingNames: {'Same Thing'},
      ideas: (_) async {
        calls++;
        return [ai('Same Thing')];
      },
    );
    expect(res.plan, hasLength(draft.length));
    expect(calls, 1);
  });

  test('builds AI meals around food the plan does not use yet, soonest first', () {
    final picked = PlanFiller.pickFor(draft, pantry);
    expect(picked.map((p) => p.name), ['Bananas'], reason: 'eggs and milk are used by Scrambled Eggs');
  });

  test('a full plan is left alone', () async {
    final res = await PlanFiller.fill(
      draft: draft,
      days: draft.length,
      pantry: pantry,
      start: start,
      ideas: (_) async => fail('should not call the AI'),
    );
    expect(res.added, isEmpty);
  });
}
