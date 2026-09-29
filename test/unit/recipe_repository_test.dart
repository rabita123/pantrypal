// Recipe persistence round-trips through SharedPreferences JSON, so a
// serialisation gap silently loses user data. These tests pin the mapping.

import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/data/recipe_seeds.dart';
import 'package:pantrypal/features/recipes/data/repositories/recipe_repository.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';

import '../support/fixtures.dart';
import '../support/plugin_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecipeRepository repo;

  setUp(() {
    stubSharedPreferences();
    repo = RecipeRepository();
  });

  group('Persistence round-trip', () {
    test('an empty store returns no recipes', () async {
      expect(await repo.getAll(), isEmpty);
    });

    test('saves and reads back every field', () async {
      final r = recipe(
        name: 'Shakshuka',
        servings: 4,
        prepMinutes: 10,
        cookMinutes: 25,
        cuisine: Cuisine.middleEastern,
        dietaryTags: {DietaryTag.vegetarian, DietaryTag.glutenFree},
        ingredients: [
          ingredient('Eggs', quantity: 4, category: FoodCategory.eggs),
          ingredient('Tomatoes', quantity: 400, unit: 'g', category: FoodCategory.vegetables),
        ],
        steps: ['Fry onions', 'Add tomatoes', 'Crack in eggs'],
      );

      await repo.save(r);
      final read = (await repo.getAll()).single;

      expect(read.id, r.id);
      expect(read.name, 'Shakshuka');
      expect(read.servings, 4);
      expect(read.prepMinutes, 10);
      expect(read.cookMinutes, 25);
      expect(read.cuisine, Cuisine.middleEastern);
      expect(read.dietaryTags, {DietaryTag.vegetarian, DietaryTag.glutenFree});
      expect(read.ingredients.length, 2);
      expect(read.ingredients.first.name, 'Eggs');
      expect(read.ingredients[1].unit, 'g');
      expect(read.steps, ['Fry onions', 'Add tomatoes', 'Crack in eggs']);
    });

    test('saving the same id updates rather than duplicates', () async {
      final r = recipe(id: 'r1', name: 'Original');
      await repo.save(r);
      await repo.save(r.copyWith(name: 'Renamed'));

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.single.name, 'Renamed');
    });

    test('deletes a recipe', () async {
      final r = recipe(id: 'r2');
      await repo.save(r);
      await repo.delete('r2');
      expect(await repo.getAll(), isEmpty);
    });

    test('deleting an unknown id is a no-op', () async {
      await repo.save(recipe(id: 'r3'));
      await repo.delete('does-not-exist');
      expect((await repo.getAll()).length, 1);
    });

    test('toggles favourite on and off', () async {
      await repo.save(recipe(id: 'r4', isFavorite: false));

      await repo.toggleFavorite('r4');
      expect((await repo.getAll()).single.isFavorite, isTrue);

      await repo.toggleFavorite('r4');
      expect((await repo.getAll()).single.isFavorite, isFalse);
    });

    test('preserves a recipe with no ingredients or steps', () async {
      await repo.save(recipe(id: 'r5', ingredients: [], steps: []));
      final read = (await repo.getAll()).single;
      expect(read.ingredients, isEmpty);
      expect(read.steps, isEmpty);
    });

    test('survives unicode and emoji in names and steps', () async {
      await repo.save(recipe(
        id: 'r6',
        name: 'Crème Brûlée 🍮',
        steps: ['Chauffer à 180°C', 'Caraméliser 🔥'],
      ));
      final read = (await repo.getAll()).single;
      expect(read.name, 'Crème Brûlée 🍮');
      expect(read.steps.last, 'Caraméliser 🔥');
    });
  });

  group('Seeding', () {
    test('seeds the built-in recipe library on first run', () async {
      await repo.seedIfEmpty();
      final all = await repo.getAll();
      expect(all, isNotEmpty);
      expect(all.length, kSeedRecipes.length + kKidSeedRecipes.length);
    });

    test('seeding twice does not duplicate', () async {
      await repo.seedIfEmpty();
      final first = (await repo.getAll()).length;
      await repo.seedIfEmpty();
      expect((await repo.getAll()).length, first);
    });

    test('every seeded recipe is usable — name, steps and ingredients', () async {
      await repo.seedIfEmpty();
      for (final r in await repo.getAll()) {
        expect(r.name, isNotEmpty, reason: 'recipe ${r.id} has no name');
        expect(r.ingredients, isNotEmpty, reason: '${r.name} has no ingredients');
        expect(r.steps, isNotEmpty, reason: '${r.name} has no steps');
        expect(r.servings, greaterThan(0), reason: '${r.name} has 0 servings');
        expect(r.totalMinutes, greaterThan(0), reason: '${r.name} takes 0 minutes');
      }
    });

    test('seeded recipe ids are unique', () async {
      await repo.seedIfEmpty();
      final all = await repo.getAll();
      expect(all.map((r) => r.id).toSet().length, all.length);
    });
  });

  group('Recipe domain helpers', () {
    test('formats total time as minutes or hours', () {
      expect(recipe(prepMinutes: 10, cookMinutes: 20).timeLabel, '30min');
      expect(recipe(prepMinutes: 30, cookMinutes: 30).timeLabel, '1h');
      expect(recipe(prepMinutes: 30, cookMinutes: 45).timeLabel, '1h 15min');
    });

    test('scales an ingredient quantity', () {
      final scaled = ingredient('Rice', quantity: 200).scaleBy(2.5);
      expect(scaled.quantity, 500);
      expect(scaled.name, 'Rice');
    });

    test('formats display quantity without trailing zeros', () {
      expect(ingredient('X', quantity: 2).displayQuantity, '2');
      expect(ingredient('X', quantity: 2.5).displayQuantity, '2.5');
    });

    test('parses dietary tags, returning null for unknown ones', () {
      expect(DietaryTag.fromString('vegan'), DietaryTag.vegan);
      expect(DietaryTag.fromString('carnivore'), isNull);
    });

    test('falls back to "other" for an unknown cuisine', () {
      expect(Cuisine.fromString('italian'), Cuisine.italian);
      expect(Cuisine.fromString('martian'), Cuisine.other);
    });
  });
}
