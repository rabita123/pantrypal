import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/domain/services/cook_tonight_service.dart';

import '../support/fixtures.dart';

void main() {
  group('Ingredient matching', () {
    test('matches an exact ingredient name', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('Milk')])],
        pantryItems: [item(name: 'Milk')],
      );
      expect(results.single.foundCount, 1);
      expect(results.single.canCookNow, isTrue);
    });

    test('matches on a shared token', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('Chicken Breast')])],
        pantryItems: [item(name: 'Chicken', category: FoodCategory.meat)],
      );
      expect(results.single.foundCount, 1);
    });

    test('matches singular ingredient against plural pantry name', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('Tomato')])],
        pantryItems: [item(name: 'Tomatoes', category: FoodCategory.vegetables)],
      );
      expect(results.single.foundCount, 1);
    });

    test('matches "Egg" recipe ingredient against "Eggs" in the pantry', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('Egg')])],
        pantryItems: [item(name: 'Eggs', category: FoodCategory.eggs)],
      );
      expect(results.single.foundCount, 1);
    });

    test('is case insensitive', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('SPINACH')])],
        pantryItems: [item(name: 'spinach', category: FoodCategory.vegetables)],
      );
      expect(results.single.foundCount, 1);
    });

    test('does not match unrelated items via a generic descriptor', () {
      // "sauce" is a stop word, so soy sauce must not satisfy tomato sauce.
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('Tomato Sauce')])],
        pantryItems: [item(name: 'Soy Sauce', category: FoodCategory.condiments)],
      );
      expect(results, isEmpty, reason: '0% match results are filtered out');
    });

    test('reports a partial match honestly', () {
      final results = CookTonightService.match(
        recipes: [
          recipe(ingredients: [
            ingredient('Milk'),
            ingredient('Eggs'),
            ingredient('Flour'),
          ])
        ],
        pantryItems: [item(name: 'Milk')],
      );
      final r = results.single;
      expect(r.foundCount, 1);
      expect(r.totalCount, 3);
      expect(r.matchPercent, closeTo(1 / 3, 0.001));
      expect(r.canCookNow, isFalse);
    });
  });

  group('Pantry eligibility', () {
    test('ignores expired pantry items', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('Milk')])],
        pantryItems: [item(name: 'Milk', daysFromNow: -2)],
      );
      expect(results, isEmpty);
    });

    test('ignores consumed and wasted items', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('Milk')])],
        pantryItems: [
          item(name: 'Milk', isConsumed: true),
          item(name: 'Milk', isWasted: true),
        ],
      );
      expect(results, isEmpty);
    });
  });

  group('Ranking', () {
    test('recipes using expiring items rank first', () {
      final urgent = recipe(name: 'Uses Expiring', ingredients: [ingredient('Yogurt')]);
      final calm = recipe(name: 'Uses Fresh', ingredients: [ingredient('Rice')]);

      final results = CookTonightService.match(
        recipes: [calm, urgent],
        pantryItems: [
          item(name: 'Yogurt', daysFromNow: 1),
          item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 100),
        ],
      );

      expect(results.first.recipe.name, 'Uses Expiring');
      expect(results.first.expiringCount, 1);
    });

    test('ties break on match percentage', () {
      final full = recipe(name: 'Full', ingredients: [ingredient('Rice')]);
      final partial = recipe(
        name: 'Partial',
        ingredients: [ingredient('Rice'), ingredient('Saffron')],
      );

      final results = CookTonightService.match(
        recipes: [partial, full],
        pantryItems: [
          item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 100),
        ],
      );

      expect(results.first.recipe.name, 'Full');
    });

    test('drops recipes with no matching ingredient at all', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('Saffron')])],
        pantryItems: [item(name: 'Milk')],
      );
      expect(results, isEmpty);
    });
  });

  group('Edge cases', () {
    test('empty pantry yields no suggestions', () {
      expect(
        CookTonightService.match(recipes: [recipe()], pantryItems: []),
        isEmpty,
      );
    });

    test('empty recipe book yields no suggestions', () {
      expect(
        CookTonightService.match(recipes: [], pantryItems: [item()]),
        isEmpty,
      );
    });

    test('a recipe with no ingredients is not cookable', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [])],
        pantryItems: [item()],
      );
      expect(results, isEmpty);
      // matchPercent guards against divide-by-zero
      expect(
        CookTonightResult(
          recipe: recipe(),
          matches: const [],
          foundCount: 0,
          totalCount: 0,
          expiringCount: 0,
        ).matchPercent,
        0,
      );
    });

    test('the sentinel item never leaks into a match', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('__sentinel__')])],
        pantryItems: [item(name: 'Milk')],
      );
      expect(results, isEmpty);
    });
  });

  staplesAndRankingTests();
}

// ── Appended: staples and smarter ranking ────────────────────────────────────

void staplesAndRankingTests() {
  group('Assumed staples', () {
    test('salt, pepper, water and oil never count as missing', () {
      final results = CookTonightService.match(
        recipes: [
          recipe(ingredients: [
            ingredient('Eggs'),
            ingredient('Salt'),
            ingredient('Black Pepper'),
            ingredient('Olive Oil'),
          ])
        ],
        pantryItems: [item(name: 'Eggs', category: FoodCategory.eggs)],
      );
      final r = results.single;
      expect(r.canCookNow, isTrue);
      expect(r.missingNames, isEmpty);
    });

    test('bell pepper is a real ingredient, not the pepper staple', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('Eggs'), ingredient('Bell Pepper')])],
        pantryItems: [item(name: 'Eggs', category: FoodCategory.eggs)],
      );
      expect(results.single.missingNames, ['Bell Pepper']);
    });

    test('a recipe made only of staples is never suggested', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('Salt'), ingredient('Water')])],
        pantryItems: [item(name: 'Milk')],
      );
      expect(results, isEmpty);
    });
  });

  group('Smarter ranking', () {
    test('a full match beats a barely-related recipe that uses one expiring item', () {
      final full = recipe(name: 'Full', ingredients: [ingredient('Rice'), ingredient('Beans')]);
      final stretch = recipe(
        name: 'Stretch',
        ingredients: [
          ingredient('Yogurt'),
          ingredient('Saffron'),
          ingredient('Lamb'),
          ingredient('Almonds'),
          ingredient('Dates'),
        ],
      );
      final results = CookTonightService.match(
        recipes: [stretch, full],
        pantryItems: [
          item(name: 'Yogurt', daysFromNow: 1),
          item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 100),
          item(name: 'Beans', category: FoodCategory.grains, daysFromNow: 100),
        ],
      );
      expect(results.first.recipe.name, 'Full');
    });

    test('missingNames lists only what is genuinely absent', () {
      final results = CookTonightService.match(
        recipes: [recipe(ingredients: [ingredient('Milk'), ingredient('Flour'), ingredient('Eggs')])],
        pantryItems: [item(name: 'Milk')],
      );
      expect(results.single.missingNames, ['Flour', 'Eggs']);
      expect(results.single.missingCount, 2);
    });
  });
}
