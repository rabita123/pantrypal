// Shared test fixtures for the PantryPal test harness.
//
// Builders here keep tests readable: every test declares only the fields it
// actually asserts on, and relies on these defaults for the rest.

import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';

int _seq = 0;
String nextId([String prefix = 'id']) => '$prefix-${_seq++}';

/// A pantry item expiring [daysFromNow] days from now (negative = expired).
PantryItem item({
  String? id,
  String name = 'Milk',
  FoodCategory category = FoodCategory.dairy,
  StorageLocation location = StorageLocation.fridge,
  double quantity = 1,
  String unit = 'item',
  int daysFromNow = 10,
  double? price,
  bool isConsumed = false,
  bool isWasted = false,
}) {
  final now = DateTime.now();
  return PantryItem(
    id: id ?? nextId('item'),
    name: name,
    category: category,
    location: location,
    quantity: quantity,
    unit: unit,
    // Noon on the target calendar day: expiry is counted in calendar days, so
    // this is stable whatever time of day the test runs.
    expiryDate: DateTime(now.year, now.month, now.day + daysFromNow, 12),
    addedDate: now,
    price: price,
    isConsumed: isConsumed,
    isWasted: isWasted,
  );
}

ShoppingItem shoppingItem({
  String? id,
  String name = 'Bread',
  FoodCategory category = FoodCategory.grains,
  double quantity = 1,
  String unit = 'item',
  bool isChecked = false,
}) {
  return ShoppingItem(
    id: id ?? nextId('shop'),
    name: name,
    category: category,
    quantity: quantity,
    unit: unit,
    isChecked: isChecked,
    addedDate: DateTime.now(),
  );
}

RecipeIngredient ingredient(
  String name, {
  double quantity = 1,
  String unit = 'item',
  FoodCategory category = FoodCategory.other,
}) =>
    RecipeIngredient(
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
    );

Recipe recipe({
  String? id,
  String name = 'Test Recipe',
  List<RecipeIngredient>? ingredients,
  List<String>? steps,
  int servings = 2,
  int prepMinutes = 10,
  int cookMinutes = 20,
  Set<DietaryTag> dietaryTags = const {},
  Cuisine cuisine = Cuisine.any,
  bool isFavorite = false,
}) {
  return Recipe(
    id: id ?? nextId('recipe'),
    name: name,
    servings: servings,
    prepMinutes: prepMinutes,
    cookMinutes: cookMinutes,
    ingredients: ingredients ?? [ingredient('Milk')],
    steps: steps ?? const ['Step one'],
    dietaryTags: dietaryTags,
    cuisine: cuisine,
    isFavorite: isFavorite,
    createdAt: DateTime(2026, 1, 1),
  );
}

// ── Raw OCR text samples ────────────────────────────────────────────────────
// Each sample mirrors a real receipt layout the parser claims to support.

/// Strategy 1: name and price on the same line.
const kReceiptSameLine = '''
FRESH MART
123 Market Street
Whole Milk 2L 3.49
Free Range Eggs 12ct 4.29
Chicken Breast 1.2kg 9.99
Toilet Paper 9pk 6.50
SUBTOTAL 24.27
TAX 1.21
TOTAL 25.48
VISA 25.48
THANK YOU
''';

/// Strategy 2: OCR pushed each price onto the line after the item.
const kReceiptAdjacentLine = '''
CORNER GROCER
Cheddar Cheese
4.15
Bananas
1.80
Sourdough Bread
2.99
TOTAL
8.94
''';

/// Strategy 0: numbered item list with a following data row (South Asian style).
const kReceiptNumbered = '''
SHWAPNO SUPER SHOP
BIN No: 000123456
Invoice No: INV-9931
SL Description Qty MRP Amount
1. FRESH MILK 1LTR 50561
8901234567 1 95 95
2. BASMATI RICE 5KG 50534
8901234568 1 650 650
3. MUSTARD OIL 1LTR
8901234569 1 235 235
Sub Total 980
Net Payable 980
''';

/// Strategy 3: two-column OCR — all names first, then all prices.
const kReceiptColumnSplit = '''
VALUE FOODS
Store #4471
Greek Yogurt
Spinach
Salmon Fillet
5.25
2.10
12.40
TOTAL
19.75
''';

/// No prices at all — freetext fallback (a handwritten or typed list).
const kFreeTextList = '''
milk
eggs
spinach
chicken
shampoo
''';

/// Nothing food-like — parser should return an empty list.
const kNonFoodText = '''
PARKING RECEIPT
Bay 22
Duration 2h
Thank you
''';
