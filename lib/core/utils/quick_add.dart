import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/core/constants/starter_foods.dart';
import 'package:pantrypal/core/utils/grocery_ocr_parser.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:uuid/uuid.dart';

/// Turns the least possible input — a few names — into ready-to-store pantry
/// items with sensible category, storage place and expiry.
class QuickAdd {
  static const _uuid = Uuid();

  /// "milk, 2 eggs and spinach" → ["milk", "2 eggs", "spinach"]
  static List<String> splitNames(String input) {
    return input
        .split(RegExp(r'[,;\n&]|\band\b', caseSensitive: false))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Splits an optional leading quantity off a typed entry: "2 eggs" → (2, "eggs").
  static ({double quantity, String name}) parseLine(String line) {
    final m = RegExp(r'^(\d+(?:\.\d+)?)(?:\s*x\s*|\s+)(.+)$', caseSensitive: false)
        .firstMatch(line.trim());
    if (m == null) return (quantity: 1, name: line.trim());
    final qty = double.tryParse(m.group(1)!) ?? 1;
    final rest = m.group(2)!.trim();
    if (rest.isEmpty || qty <= 0 || qty > 99) return (quantity: 1, name: line.trim());
    return (quantity: qty, name: rest);
  }

  static List<PantryItem> parse(String input, {DateTime? now}) {
    return splitNames(input)
        .map((line) {
          final p = parseLine(line);
          return itemFor(p.name, quantity: p.quantity, now: now);
        })
        .toList();
  }

  /// Builds an item for a bare name using the starter table first, then the
  /// category defaults.
  static PantryItem itemFor(
    String rawName, {
    double quantity = 1,
    FoodCategory? category,
    double? price,
    DateTime? now,
  }) {
    final name = _titleCase(rawName.trim());
    final starter = starterFoodFor(name);
    final cat = category ?? starter?.category ?? GroceryOcrParser.guessCategory(name);
    final days = starter?.shelfDays ?? AppConstants.defaultShelfLife[cat.name] ?? 14;
    return PantryItem(
      id: _uuid.v4(),
      name: name,
      category: cat,
      location: starter?.location ?? cat.defaultLocation,
      quantity: quantity,
      unit: 'item',
      expiryDate: PantryItem.expiryInDays(days, from: now),
      addedDate: now ?? DateTime.now(),
      price: price,
      isConsumed: false,
      isWasted: false,
    );
  }

  static PantryItem fromStarter(StarterFood f, {DateTime? now}) => PantryItem(
        id: _uuid.v4(),
        name: f.name,
        category: f.category,
        location: f.location,
        quantity: 1,
        unit: 'item',
        expiryDate: PantryItem.expiryInDays(f.shelfDays, from: now),
        addedDate: now ?? DateTime.now(),
        isConsumed: false,
        isWasted: false,
      );

  static String _titleCase(String s) => s
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}
