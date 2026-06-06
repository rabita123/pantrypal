import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

class GroceryOcrParser {
  static List<Map<String, dynamic>> parseReceipt(String rawText) {
    final receiptItems = _parseAsReceipt(rawText);
    if (receiptItems.isNotEmpty) return receiptItems;

    // Fallback: free-text items, then try to attach any standalone prices in order
    final freeItems = _parseAsFreeText(rawText);
    if (freeItems.isEmpty) return [];

    final standalonePrice = RegExp(r'^\$?\s*(\d+[.,]\d{1,2}|\d{3,})\s*[A-Z]?\s*$');
    final negativePattern = RegExp(r'-\s*\$?\s*\d+');
    final prices = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .where((l) => !negativePattern.hasMatch(l))
        .map((l) => standalonePrice.firstMatch(l))
        .whereType<RegExpMatch>()
        .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0.0)
        .where((p) => p >= 0.10 && p < 100000.0) // allow high-value currencies like Taka
        .toList();

    if (prices.length == freeItems.length) {
      return freeItems.asMap().entries.map((e) {
        return {...e.value, 'price': prices[e.key]};
      }).toList();
    }

    return freeItems;
  }

  static List<Map<String, dynamic>> _parseAsReceipt(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Matches decimal prices (6.17, 1.80) OR whole-number amounts ≥ 3 digits (363, 1250)
    // 3-digit minimum avoids matching quantities like "1", "2", pack sizes etc.
    final priceAtEnd    = RegExp(r'\$?\s*(\d+[.,]\d{1,2}|\d{3,})\s*[A-Z]?\s*$');
    final standalonePrice = RegExp(r'^\$?\s*(\d+[.,]\d{1,2}|\d{3,})\s*[A-Z]?\s*$');
    final negativePattern = RegExp(r'-\s*\$?\s*\d+');
    final qtyPattern      = RegExp(r'^(\d+)\s*[xX@]\s*(.+)');
    final weightPattern   = RegExp(r'(\d+\.?\d*)\s*(kg|g|lbs|lb|11b|1b|oz|0z|l|ml|L)', caseSensitive: false);
    final packPattern     = RegExp(r'\b\d+\s*(ct|pk|pack|ea|pc|pcs)\b', caseSensitive: false);

    Map<String, dynamic>? buildItem(String rawName, double price) {
      if (price < 0.10) return null;
      String name = rawName;
      double quantity = 1.0;
      String unit = 'item';

      final qtyMatch = qtyPattern.firstMatch(name);
      if (qtyMatch != null) {
        quantity = double.tryParse(qtyMatch.group(1)!) ?? 1.0;
        name = qtyMatch.group(2)!.trim();
      }
      final wm = weightPattern.firstMatch(name);
      if (wm != null) {
        quantity = double.tryParse(wm.group(1)!) ?? 1.0;
        final ru = wm.group(2)!.toLowerCase();
        unit = (ru == '11b' || ru == '1b') ? 'lb' : ru == '0z' ? 'oz' : ru;
        name = name.replaceAll(wm.group(0)!, '').trim();
      }
      name = name.replaceAll(packPattern, '').trim();
      name = _cleanName(name);
      if (name.length < 2) return null;
      // Only apply non-food filter to ASCII names — non-English scripts pass through
      final isAscii = RegExp(r'^[\x00-\x7F]+$').hasMatch(name);
      if (isAscii && _isNonFood(name.toLowerCase())) return null;
      final category = _guessCategory(name.toLowerCase());
      return {
        'name': name.trim(),
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'price': price,
        'estimatedExpiryDays': AppConstants.defaultShelfLife[category.name] ?? 14,
      };
    }

    // ── Strategy 0: numbered item list (South Asian / structured receipts) ────
    // Format:  "N. ITEM NAME [optional_suffix]"   ← description line
    //          "SKU/barcode  QTY  MRP  AMOUNT"    ← data line (may be OCR-garbled)
    // Runs unconditionally — section boundaries used only to narrow the search.
    {
      final numberedItem = RegExp(r'^\d+\.\s+(.+)');
      // Last decimal OR last 2-5 digit integer on any line = amount
      final lastDecimal = RegExp(r'(\d+[.,]\d{1,2})\s*$');
      final lastInt     = RegExp(r'\b(\d{2,5})\s*$');

      // Optional: narrow to item section if we can detect start/end
      int s0 = 0, s1 = lines.length;
      for (int i = 0; i < lines.length; i++) {
        final l = lines[i].toLowerCase();
        if (l.contains('description') || RegExp(r'\bsl\b\.?').hasMatch(l) ||
            l.contains('item') && l.contains('qty')) {
          s0 = i + 1; break;
        }
      }
      for (int i = s0; i < lines.length; i++) {
        final l = lines[i].toLowerCase();
        if (l.contains('sub total') || l.contains('subtotal') ||
            l.contains('net payable') || l.contains('grand total') ||
            l.contains('inword') || l.contains('in word')) {
          s1 = i; break;
        }
      }
      // If section not detected, still search full text
      final searchLines = lines.sublist(s0, s1);

      final numberedItems = <Map<String, dynamic>>[];
      for (int i = 0; i < searchLines.length; i++) {
        final nm = numberedItem.firstMatch(searchLines[i]);
        if (nm == null) continue;

        String rawName = nm.group(1)!;
        // Strip trailing numeric product codes  e.g. "50561", "50534"
        rawName = rawName.replaceAll(RegExp(r'\s+\d{4,}\s*$'), '').trim();
        // Strip trailing all-caps/digit codes   e.g. "S00021", "(M)"
        rawName = rawName.replaceAll(RegExp(r'\s+\(?[A-Z0-9]{3,}\)?\s*$'), '').trim();
        // Strip weight suffix already in the name  e.g. "200GM", "350GM"
        rawName = rawName.replaceAll(RegExp(r'\s+\d+\s*[Gg][Mm]\s*$'), '').trim();

        // Find price: scan next 1–2 lines for the amount
        double price = 0.0;
        for (int j = i + 1; j <= i + 2 && j < searchLines.length; j++) {
          final nextLine = searchLines[j];
          // Prefer decimal amount (e.g. 26.40, 45.00)
          final dm = lastDecimal.firstMatch(nextLine);
          if (dm != null) {
            price = double.tryParse(dm.group(1)!.replaceAll(',', '.')) ?? 0.0;
            if (price > 0.01) break;
          }
          // Fall back to last integer ≥ 2 digits (e.g. Taka: 45, 135)
          // Only if the line looks like a data row (≥ 3 whitespace-separated tokens)
          final tokens = nextLine.trim().split(RegExp(r'\s+'));
          if (tokens.length >= 3) {
            final im = lastInt.firstMatch(nextLine);
            if (im != null) {
              price = double.tryParse(im.group(1)!) ?? 0.0;
              if (price > 0.01) break;
            }
          }
        }
        if (price < 0.01) continue;

        final item = buildItem(rawName, price);
        if (item != null) numberedItems.add(item);
      }
      if (numberedItems.isNotEmpty) return numberedItems.take(30).toList();
    }

    // ── Strategy 1: price on the same line ──────────────────────────────────
    final sameLineItems = <Map<String, dynamic>>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_shouldSkipLine(line.toLowerCase())) continue;
      if (negativePattern.hasMatch(line)) continue;
      final m = priceAtEnd.firstMatch(line);
      if (m == null) continue;
      final rawName = line.substring(0, m.start).trim();
      final price = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0.0;
      final item = buildItem(rawName, price);
      if (item != null) sameLineItems.add(item);
    }
    if (sameLineItems.isNotEmpty) return sameLineItems.take(30).toList();

    // ── Strategy 2: adjacent-line (OCR puts price on very next line) ────────
    final adjacentItems = <Map<String, dynamic>>[];
    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i];
      if (_shouldSkipLine(line.toLowerCase())) continue;
      if (negativePattern.hasMatch(line)) continue;
      if (priceAtEnd.hasMatch(line)) continue; // already tried
      final nextLine = lines[i + 1].trim();
      final nm = standalonePrice.firstMatch(nextLine);
      if (nm == null) continue;
      final price = double.tryParse(nm.group(1)!.replaceAll(',', '.')) ?? 0.0;
      final item = buildItem(line.trim(), price);
      if (item != null) {
        adjacentItems.add(item);
        i++; // consume price line
      }
    }
    if (adjacentItems.isNotEmpty) return adjacentItems.take(30).toList();

    // ── Strategy 3: column split (all names first, then all prices) ─────────
    // OCR often reads a two-column receipt as: all item names, then all prices.
    // Filter nameBlock strictly so header lines (SUPERMARKET, Store #123) are excluded.
    final nameBlock = <String>[];
    final priceBlock = <double>[];
    for (final line in lines) {
      if (_shouldSkipLine(line.toLowerCase())) continue;
      if (negativePattern.hasMatch(line)) continue;
      final sm = standalonePrice.firstMatch(line);
      if (sm != null) {
        final p = double.tryParse(sm.group(1)!.replaceAll(',', '.')) ?? 0.0;
        // Exclude totals (usually > $100 for full shop or suspiciously large)
        if (p >= 0.10 && p < 100000.0) priceBlock.add(p);
      } else {
        // Strict candidate filter: must look like an actual food item
        if (line.length < 3 || line.length > 60) continue;
        if (line.contains('#')) continue;
        if (RegExp(r'^\d').hasMatch(line)) continue;
        if (RegExp(r'^[A-Z\s]+$').hasMatch(line)) continue; // all-caps store headers
        if (_isNonFood(line.toLowerCase())) continue;
        // Must resolve to a known food category OR contain a common grocery keyword
        final cleaned = _cleanName(line).toLowerCase();
        final cat = _guessCategory(cleaned);
        final isFood = cat != FoodCategory.other ||
            AppConstants.commonItems.any((k) => cleaned.contains(k));
        if (!isFood) continue;
        nameBlock.add(line);
      }
    }

    if (priceBlock.isNotEmpty && nameBlock.isNotEmpty) {
      // If more names than prices, take the LAST N names
      // (headers appear first, food items last in the name block)
      final n = priceBlock.length;
      final candidates = nameBlock.length > n
          ? nameBlock.sublist(nameBlock.length - n)
          : nameBlock;

      final columnItems = <Map<String, dynamic>>[];
      final count = candidates.length < priceBlock.length ? candidates.length : priceBlock.length;
      for (int i = 0; i < count; i++) {
        final item = buildItem(candidates[i], priceBlock[i]);
        if (item != null) columnItems.add(item);
      }
      if (columnItems.isNotEmpty) return columnItems.take(30).toList();
    }

    return [];
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
    if (lower.length < 3) return true;
    // Pure-digit lines (barcodes, quantities)
    if (RegExp(r'^\d+\.?\d*\s*$').hasMatch(lower)) return true;
    if (lower.contains('tel:') || lower.contains('http') || lower.contains('www.')) return true;
    // SKU / barcode data lines: 6+ alphanum chars at start followed by digits
    if (RegExp(r'^[a-z0-9]{6,}\s+\d').hasMatch(lower)) return true;
    // Very short OCR fragments that are clearly barcode residue (e.g. "so", "sO", "wo")
    // — 1–3 chars that are mostly lowercase letters + digits, no real word meaning
    if (lower.length <= 3 && RegExp(r'^[a-z]{1,2}\d').hasMatch(lower)) return true;
    // Lines that are only uppercase letters + digits with no spaces (product codes)
    if (RegExp(r'^[A-Z0-9]{5,}$').hasMatch(lower.trim())) return true;
    // Phone / BIN numbers: line starts with 6+ digits
    if (RegExp(r'^\d{6,}').hasMatch(lower)) return true;
    // Lines containing only a code+number pattern like "(M)" or "0."
    if (RegExp(r'^\(?\w{1,3}\)?\.?\s*$').hasMatch(lower.trim())) return true;

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
  static FoodCategory _guessCategory(String name) {
    if (RegExp(r'\beggs?\b').hasMatch(name)) {
      return FoodCategory.eggs;
    }
    if (RegExp(r'milk|cheese|yogurt|yoghurt|cream|butter|dairy|cheddar|mozzarella|quark|fromage|kefir|cottage|ricotta|gouda|brie|feta|parmesan')
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
    if (RegExp(r'bread|rice|pasta|flour|cereal|oat|grain|wheat|noodle|vermicelli|cracker|bagel|tortilla|gnocchi|pizza|toast|bun|roll|wrap|pita|croissant|muffin|waffle|pancake|rye|barley|quinoa|couscous|bulgur|biscuit|cookie')
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
