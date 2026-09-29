import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

/// A common household food with a realistic shelf life and home.
///
/// Powers the one-tap "tap what you have" picker and gives typed quick-adds a
/// better expiry estimate than the per-category default.
class StarterFood {
  final String name;
  final String emoji;
  final FoodCategory category;
  final StorageLocation location;
  final int shelfDays;

  const StarterFood(
    this.name,
    this.emoji,
    this.category,
    this.shelfDays, {
    StorageLocation? location,
  }) : location = location ?? StorageLocation.fridge;
}

const starterFoods = <StarterFood>[
  StarterFood('Milk', '🥛', FoodCategory.dairy, 7),
  StarterFood('Eggs', '🥚', FoodCategory.eggs, 21),
  StarterFood('Butter', '🧈', FoodCategory.dairy, 30),
  StarterFood('Cheese', '🧀', FoodCategory.dairy, 21),
  StarterFood('Yogurt', '🥣', FoodCategory.dairy, 10),
  StarterFood('Chicken', '🍗', FoodCategory.meat, 2),
  StarterFood('Ground Beef', '🥩', FoodCategory.meat, 2),
  StarterFood('Fish', '🐟', FoodCategory.meat, 2),
  StarterFood('Spinach', '🥬', FoodCategory.vegetables, 4),
  StarterFood('Lettuce', '🥗', FoodCategory.vegetables, 5),
  StarterFood('Tomatoes', '🍅', FoodCategory.vegetables, 6),
  StarterFood('Cucumber', '🥒', FoodCategory.vegetables, 6),
  StarterFood('Carrots', '🥕', FoodCategory.vegetables, 21),
  StarterFood('Broccoli', '🥦', FoodCategory.vegetables, 6),
  StarterFood('Peppers', '🫑', FoodCategory.vegetables, 8),
  StarterFood('Mushrooms', '🍄', FoodCategory.vegetables, 5),
  StarterFood('Onions', '🧅', FoodCategory.vegetables, 30, location: StorageLocation.pantry),
  StarterFood('Potatoes', '🥔', FoodCategory.vegetables, 21, location: StorageLocation.pantry),
  StarterFood('Garlic', '🧄', FoodCategory.vegetables, 60, location: StorageLocation.pantry),
  StarterFood('Bananas', '🍌', FoodCategory.fruits, 5, location: StorageLocation.counter),
  StarterFood('Apples', '🍎', FoodCategory.fruits, 21),
  StarterFood('Lemons', '🍋', FoodCategory.fruits, 21),
  StarterFood('Bread', '🍞', FoodCategory.grains, 5, location: StorageLocation.counter),
  StarterFood('Rice', '🍚', FoodCategory.grains, 365, location: StorageLocation.pantry),
  StarterFood('Pasta', '🍝', FoodCategory.grains, 365, location: StorageLocation.pantry),
  StarterFood('Tortillas', '🫓', FoodCategory.grains, 14, location: StorageLocation.pantry),
  StarterFood('Juice', '🧃', FoodCategory.beverages, 10),
  StarterFood('Frozen Veg', '🧊', FoodCategory.frozen, 180, location: StorageLocation.freezer),
];

/// Looks up a starter food whose name matches [name] (case/plural tolerant).
StarterFood? starterFoodFor(String name) {
  final n = _norm(name);
  if (n.isEmpty) return null;
  for (final f in starterFoods) {
    if (_norm(f.name) == n) return f;
  }
  for (final f in starterFoods) {
    final fn = _norm(f.name);
    if (n.contains(fn) || fn.contains(n)) return f;
  }
  return null;
}

String _norm(String s) {
  var n = s.toLowerCase().trim().replaceAll(RegExp(r'[^a-z ]'), '');
  if (n.endsWith('ies') && n.length > 4) return '${n.substring(0, n.length - 3)}y';
  if (n.endsWith('oes')) return n.substring(0, n.length - 2);
  if (n.endsWith('s') && !n.endsWith('ss') && n.length > 3) return n.substring(0, n.length - 1);
  return n;
}
