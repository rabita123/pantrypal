import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

class GroceryOcrParser {
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

    // Allow optional $ prefix, optional trailing tax-code letter (F, T, A, N, O…)
    final pricePattern = RegExp(r'\$?\s*(\d+[.,]\d{1,2})\s*[A-Z]?\s*$');
    // Skip lines with a negative amount (discount/coupon lines)
    final negativePattern = RegExp(r'-\s*\$?\s*\d+[.,]\d');
    final qtyPattern = RegExp(r'^(\d+)\s*[xX@]\s*(.+)');
    // Also matches OCR misreads: '11b' for 'lb', '0z' for 'oz'
    final weightPattern = RegExp(
      r'(\d+\.?\d*)\s*(kg|g|lbs|lb|11b|1b|oz|0z|l|ml|L)',
      caseSensitive: false,
    );
    // Strip pack/count suffixes that aren't real units
    final packPattern = RegExp(r'\b\d+\s*(ct|pk|pack|ea|pc|pcs)\b', caseSensitive: false);

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_shouldSkipLine(lower)) continue;
      if (negativePattern.hasMatch(line)) continue;

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
        final rawUnit = weightMatch.group(2)!.toLowerCase();
        // Normalise OCR misreads back to real unit names
        unit = rawUnit == '11b' || rawUnit == '1b' ? 'lb'
             : rawUnit == '0z' ? 'oz'
             : rawUnit;
        name = name.replaceAll(weightMatch.group(0)!, '').trim();
      }

      // Strip pack/count labels like "12pk", "8ct"
      name = name.replaceAll(packPattern, '').trim();

      name = _cleanName(name);
      if (name.length < 2) continue;
      if (_isNonFood(name.toLowerCase())) continue;
      // Skip bare single-word category names that are almost always OCR
      // split artefacts (e.g. "Cheese 1.64" from "Cottage Cheese  1.64")
      if (_isBareCategory(name)) continue;

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
    // Pure-digit lines (barcodes, quantities without names)
    if (RegExp(r'^\d+$').hasMatch(lower)) return true;
    if (lower.contains('tel:') || lower.contains('http') || lower.contains('www.')) return true;
    if (lower.length < 3) return true;

    return AppConstants.skipKeywords.any((k) => lower.contains(k));
  }

  static String _cleanName(String name) {
    name = name.replaceAll(RegExp(r'[*#@!]'), '');
    // Strip unit-price segments like "à 4.50 CHF" or "@ 22.00 EUR"
    name = name.replaceAll(
        RegExp(r'\s*[àa@]\s*\d+[.,]\d+\s*[A-Z]{2,4}', caseSensitive: false), '');
    // Strip trailing currency+amount
    name = name.replaceAll(
        RegExp(r'\s*\d+[.,]\d+\s*[A-Z]{2,4}', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\s*[A-Z]{2,4}\s*$'), '');
    name = name.replaceAll(RegExp(r'\s{2,}'), ' ');
    name = name.replaceAll(RegExp(r'^\d+\s+'), ''); // leading stand-alone number
    return name.trim();
  }

  // Unambiguous non-food single words (never appear in food product names)
  static final _nonFoodRegex = RegExp(
    r'\b(toilet|shampoo|conditioner|detergent|bleach|disinfectant|'
    r'battery|batteries|magazine|newspaper|lottery|'
    r'toothpaste|toothbrush|mouthwash|floss|'
    r'deodorant|antiperspirant|razor|shaving|'
    r'diaper|nappy|sanitary|tampon|'
    r'bandage|plaster|antiseptic|'
    r'wipes?|laundry|softener|dryer|'
    r'napkin|serviette|tissue|towel|'
    r'foil|cling|sponge|scrubber)\b',
    caseSensitive: false,
  );

  static bool _isNonFood(String name) => _nonFoodRegex.hasMatch(name);

  // Single-word names that are just a food category label are almost always
  // OCR split artefacts — e.g. "Cottage Cheese 1.64" scanned as two lines
  // produces a spurious "Cheese 1.64" entry.
  static final _bareCategoryWords = {
    'cheese', 'milk', 'cream', 'butter', 'yogurt', 'yoghurt',
    'meat', 'chicken', 'beef', 'pork', 'fish', 'eggs', 'egg',
    'bread', 'rice', 'pasta', 'flour', 'cereal',
    'juice', 'water', 'soda', 'coffee', 'tea',
    'sauce', 'oil', 'sugar', 'salt',
    'fruit', 'vegetable', 'produce', 'frozen', 'organic',
  };

  static bool _isBareCategory(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    return words.length == 1 && _bareCategoryWords.contains(words.first.toLowerCase());
  }

  static FoodCategory _guessCategory(String name) {
    if (RegExp(r'milk|cheese|yogurt|yoghurt|cream|butter|dairy|cheddar|mozzarella|quark|fromage|egg|eggs|kefir|cottage|ricotta|gouda|brie|feta|parmesan')
        .hasMatch(name)) {
      return FoodCategory.dairy;
    }
    if (RegExp(r'chicken|beef|pork|lamb|fish|salmon|tuna|shrimp|prawn|meat|steak|sausage|wurst|fleisch|poulet|veal|turkey|bacon|ham|mince|meatball|salami|pepperoni|deli|seafood|tilapia|cod|haddock|crab|lobster|sardine')
        .hasMatch(name)) {
      return FoodCategory.meat;
    }
    if (RegExp(r'apple|banana|orange|grape|mango|berry|fruit|peach|plum|melon|lemon|lime|obst|cherry|pear|kiwi|pineapple|watermelon|strawberr|blueberr|raspberr|blackberr|avocado|fig|date|apricot|nectarine|clementine|grapefruit|pomegranate')
        .hasMatch(name)) {
      return FoodCategory.fruits;
    }
    if (RegExp(r'lettuce|spinach|broccoli|carrot|potato|onion|tomato|pepper|garlic|cabbage|celery|cucumber|vegetable|veg|salad|aubergine|eggplant|courgette|zucchini|asparagus|artichoke|leek|parsnip|turnip|beetroot|beet|radish|kale|chard|arugula|rocket|fennel|mushroom|pea|bean|corn|maize|sweet potato|squash|pumpkin|cauliflower|brussel|sprout|green bean')
        .hasMatch(name)) {
      return FoodCategory.vegetables;
    }
    if (RegExp(r'bread|rice|pasta|flour|cereal|oat|grain|wheat|noodle|cracker|bagel|tortilla|gnocchi|pizza|toast|bun|roll|wrap|pita|croissant|muffin|waffle|pancake|rye|barley|quinoa|couscous|bulgur')
        .hasMatch(name)) {
      return FoodCategory.grains;
    }
    if (RegExp(r'frozen|ice cream|popsicle|gelato|sorbet').hasMatch(name)) {
      return FoodCategory.frozen;
    }
    if (RegExp(r'juice|soda|water|drink|coffee|tea|beverage|cola|beer|wine|mineral|smoothie|lemonade|sparkling|energy drink|sports drink|kombucha|cider|latte|espresso|cappuccino|cocoa|hot chocolate')
        .hasMatch(name)) {
      return FoodCategory.beverages;
    }
    if (RegExp(r'chip|crisp|cookie|biscuit|candy|chocolate|snack|popcorn|pretzel|cake|dessert|sweets|gummy|lollipop|toffee|fudge|brownie|bar|granola bar|protein bar|nut|peanut|almond|cashew|walnut|pistachio|trail mix|dried fruit|raisin|cranberry')
        .hasMatch(name)) {
      return FoodCategory.snacks;
    }
    if (RegExp(r'sauce|ketchup|mustard|mayo|vinegar|oil|dressing|seasoning|spice|salt|herb|soup|stock|broth|gravy|jam|jelly|honey|syrup|peanut butter|almond butter|tahini|hummus|salsa|chutney|relish|marinade|soy sauce|hot sauce|bbq|curry|paste|miso')
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
