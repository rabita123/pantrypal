// Diagnostic probe for CookTonightService token matching.
// ignore_for_file: avoid_print
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/domain/services/cook_tonight_service.dart';

PantryItem p(String name) => PantryItem(
      id: name, name: name, category: FoodCategory.other,
      location: StorageLocation.fridge, quantity: 1, unit: 'item',
      expiryDate: DateTime.now().add(const Duration(days: 10)),
      addedDate: DateTime.now(), isConsumed: false, isWasted: false);

Recipe r(String ing) => Recipe(
      id: ing, name: 'Uses $ing', servings: 2, prepMinutes: 5, cookMinutes: 5,
      ingredients: [RecipeIngredient(
          name: ing, quantity: 1, unit: 'item', category: FoodCategory.other)],
      steps: const ['x'], dietaryTags: const {}, cuisine: Cuisine.any,
      isFavorite: false, createdAt: DateTime(2026));

void main() {
  const pairs = [
    ['Tomato', 'Tomatoes'], ['Potato', 'Potatoes'], ['Egg', 'Eggs'],
    ['Mango', 'Mangoes'], ['Peach', 'Peaches'], ['Carrot', 'Carrots'],
    ['Bean', 'Beans'], ['Onion', 'Onions'], ['Banana', 'Bananas'],
  ];
  for (final pair in pairs) {
    final res = CookTonightService.match(
        recipes: [r(pair[0])], pantryItems: [p(pair[1])]);
    final ok = res.isNotEmpty && res.first.foundCount == 1;
    print('${ok ? "MATCH  " : "MISS   "} recipe "${pair[0]}" vs pantry "${pair[1]}"');
  }
}
