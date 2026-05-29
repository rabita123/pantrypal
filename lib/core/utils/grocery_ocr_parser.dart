import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

class GroceryOcrParser {
  /// Parses raw OCR text from a grocery receipt (or freeform food photo) into food items.
  /// Tries receipt format first (lines ending with a price), then falls back to
  /// keyword matching for photos that aren't receipts.
  static List<Map<String, dynamic>> parseReceipt(String rawText) {
    final receiptItems = _parseAsReceipt(rawText);
    if (receiptItems.isNotEmpty) return receiptItems;
    return _parseAsFreeText(rawText);
  }

  static List<Map<String, dynamic>> _parseAsReceipt(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final items = <Map<String, dynamic>>[];
    final pricePattern = RegExp(r'(\d+[.,]\d{2})\s*$');
    final qtyPattern = RegExp(r'^(\d+)\s*[xX@]\s*(.+)');
    final weightPattern = RegExp(r'(\d+\.?\d*)\s*(kg|g|lb|oz|l|ml|L)', caseSensitive: false);

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_shouldSkipLine(lower)) continue;

      final priceMatch = pricePattern.firstMatch(line);
      if (priceMatch == null) continue;

      String name = line.substring(0, priceMatch.start).trim();
      final priceStr = priceMatch.group(1)!.replaceAll(',', '.');
      final price = double.tryParse(priceStr) ?? 0.0;
      if (price < 0.10) continue;

      double quantity = 1.0;
      String unit = 'item';
      final qtyMatch = qtyPattern.firstMatch(name);
      if (qtyMatch != null) {
        quantity = double.tryParse(qtyMatch.group(1)!) ?? 1.0;
        name = qtyMatch.group(2)!.trim();
      }

      final weightMatch = weightPattern.firstMatch(name);
      if (weightMatch != null) {
        quantity = double.tryParse(weightMatch.group(1)!) ?? 1.0;
        unit = weightMatch.group(2)!.toLowerCase();
        name = name.replaceAll(weightMatch.group(0)!, '').trim();
      }

      name = _cleanName(name);
      if (name.length < 2) continue;
      if (_isNonFood(name.toLowerCase())) continue;

      final category = _guessCategory(name.toLowerCase());
      final shelfLife = AppConstants.defaultShelfLife[category.name] ?? 14;

      items.add({
        'name': _titleCase(name),
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'price': price,
        'estimatedExpiryDays': shelfLife,
      });
    }

    return items.take(30).toList();
  }

  /// Fallback for freeform photos (no price pattern required).
  /// Matches any line that contains a known food keyword.
  static List<Map<String, dynamic>> _parseAsFreeText(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length >= 2)
        .toList();

    final seen = <String>{};
    final items = <Map<String, dynamic>>[];

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_shouldSkipLine(lower)) continue;
      if (_isNonFood(lower)) continue;

      final name = _cleanName(line);
      if (name.length < 2) continue;

      final category = _guessCategory(lower);
      final isKnownFood = category != FoodCategory.other ||
          AppConstants.commonItems.any((kw) => lower.contains(kw));
      if (!isKnownFood) continue;

      final key = name.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);

      final shelfLife = AppConstants.defaultShelfLife[category.name] ?? 14;
      items.add({
        'name': _titleCase(name),
        'category': category,
        'quantity': 1.0,
        'unit': 'item',
        'price': null,
        'estimatedExpiryDays': shelfLife,
      });
    }

    return items.take(30).toList();
  }

  static bool _shouldSkipLine(String lower) {
    return AppConstants.skipKeywords.any((k) => lower.contains(k)) ||
        RegExp(r'^\d+$').hasMatch(lower) ||
        lower.contains('tel:') ||
        lower.contains('http') ||
        lower.length < 3;
  }

  static String _cleanName(String name) {
    name = name.replaceAll(RegExp(r'[*#@!]'), '');
    // Strip unit-price segments like "à 4.50 CHF" or "@ 22.00 EUR"
    name = name.replaceAll(RegExp(r'\s*[àa@]\s*\d+[.,]\d+\s*[A-Z]{2,4}', caseSensitive: false), '');
    // Strip any remaining trailing currency+amount
    name = name.replaceAll(RegExp(r'\s*\d+[.,]\d+\s*[A-Z]{2,4}', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\s*[A-Z]{2,4}\s*$'), '');
    name = name.replaceAll(RegExp(r'\s{2,}'), ' ');
    name = name.replaceAll(RegExp(r'^\d+\s+'), ''); // leading numbers
    return name.trim();
  }

  static bool _isNonFood(String name) {
    const nonFood = [
      'bag', 'plastic', 'paper', 'napkin', 'tissue', 'soap',
      'shampoo', 'detergent', 'cleaner', 'bleach', 'batteries',
      'magazine', 'lottery', 'gift card', 'coupon',
    ];
    return nonFood.any((n) => name.contains(n));
  }

  static FoodCategory _guessCategory(String name) {
    if (RegExp(r'milk|cheese|käse|chäss|yogurt|cream|butter|dairy|cheddar|mozzarella|quark|fromage')
        .hasMatch(name)) {
      return FoodCategory.dairy;
    }
    if (RegExp(r'chicken|beef|pork|schwein|schnitzel|lamb|fish|salmon|tuna|shrimp|meat|steak|sausage|wurst|fleisch|poulet|veal|kalbfl')
        .hasMatch(name)) {
      return FoodCategory.meat;
    }
    if (RegExp(r'apple|banana|orange|grape|mango|berry|fruit|peach|plum|melon|lemon|lime|obst')
        .hasMatch(name)) {
      return FoodCategory.fruits;
    }
    if (RegExp(r'lettuce|spinach|broccoli|carrot|potato|kartoffel|onion|tomato|pepper|garlic|cabbage|celery|cucumber|vegetable|veg|salat|gemüse|rösti|spätzli|spaetzle')
        .hasMatch(name)) {
      return FoodCategory.vegetables;
    }
    if (RegExp(r'bread|brot|rice|pasta|flour|cereal|oat|grain|wheat|noodle|cracker|bagel|tortilla|knödel|gnocchi|pizza|burger|sandwich|toast|brötchen')
        .hasMatch(name)) {
      return FoodCategory.grains;
    }
    if (RegExp(r'frozen|ice cream|glace|popsicle').hasMatch(name)) {
      return FoodCategory.frozen;
    }
    if (RegExp(r'juice|saft|soda|water|wasser|drink|coffee|kaffee|latte|espresso|cappuccino|macchiato|tea|tee|beverage|cola|beer|bier|wein|wine|mineral|limonade|smoothie')
        .hasMatch(name)) {
      return FoodCategory.beverages;
    }
    if (RegExp(r'chip|crisp|cookie|biscuit|candy|chocolate|schokolad|snack|popcorn|pretzel|kuchen|cake|torte|dessert|tiramisu|mousse')
        .hasMatch(name)) {
      return FoodCategory.snacks;
    }
    if (RegExp(r'sauce|ketchup|mustard|senf|mayo|vinegar|essig|oil|öl|dressing|seasoning|spice|salt|pepper|herb|gewürz|suppe|soup')
        .hasMatch(name)) {
      return FoodCategory.condiments;
    }
    return FoodCategory.other;
  }

  static String _titleCase(String s) {
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }
}
