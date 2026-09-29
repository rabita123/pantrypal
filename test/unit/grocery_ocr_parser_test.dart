import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/utils/grocery_ocr_parser.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

import '../support/fixtures.dart';

List<String> _names(List<Map<String, dynamic>> items) =>
    items.map((i) => (i['name'] as String).toLowerCase()).toList();

Map<String, dynamic>? _find(List<Map<String, dynamic>> items, String needle) {
  for (final i in items) {
    if ((i['name'] as String).toLowerCase().contains(needle)) return i;
  }
  return null;
}

void main() {
  group('Strategy 1 — price on same line', () {
    final parsed = GroceryOcrParser.parseReceipt(kReceiptSameLine);

    test('extracts the food items', () {
      expect(_find(parsed, 'milk'), isNotNull);
      expect(_find(parsed, 'egg'), isNotNull);
      expect(_find(parsed, 'chicken'), isNotNull);
    });

    test('drops totals, tax and payment lines', () {
      final names = _names(parsed).join(' ');
      expect(names, isNot(contains('total')));
      expect(names, isNot(contains('tax')));
      expect(names, isNot(contains('visa')));
    });

    test('drops non-food household goods', () {
      expect(_find(parsed, 'toilet'), isNull);
    });

    test('attaches the price from the same line', () {
      expect(_find(parsed, 'milk')!['price'], 3.49);
      expect(_find(parsed, 'chicken')!['price'], 9.99);
    });

    test('assigns a sensible category', () {
      expect(_find(parsed, 'milk')!['category'], FoodCategory.dairy);
      expect(_find(parsed, 'egg')!['category'], FoodCategory.eggs);
      expect(_find(parsed, 'chicken')!['category'], FoodCategory.meat);
    });

    test('parses weight into quantity and unit', () {
      final chicken = _find(parsed, 'chicken')!;
      expect(chicken['quantity'], 1.2);
      expect(chicken['unit'], 'kg');
    });

    test('every item carries a positive shelf life', () {
      for (final i in parsed) {
        expect(i['estimatedExpiryDays'], isA<int>());
        expect(i['estimatedExpiryDays'] as int, greaterThan(0));
      }
    });
  });

  group('Strategy 2 — price on the following line', () {
    final parsed = GroceryOcrParser.parseReceipt(kReceiptAdjacentLine);

    test('pairs each item with the price beneath it', () {
      expect(_find(parsed, 'cheddar')!['price'], 4.15);
      expect(_find(parsed, 'banana')!['price'], 1.80);
      expect(_find(parsed, 'sourdough')!['price'], 2.99);
    });

    test('does not emit the total as an item', () {
      expect(_names(parsed).join(' '), isNot(contains('total')));
    });
  });

  group('Strategy 0 — numbered receipt with data rows', () {
    final parsed = GroceryOcrParser.parseReceipt(kReceiptNumbered);

    test('finds the numbered items', () {
      expect(parsed, isNotEmpty);
      expect(_find(parsed, 'milk'), isNotNull);
      expect(_find(parsed, 'rice'), isNotNull);
    });

    test('reads the whole-number amount from the data row', () {
      expect(_find(parsed, 'milk')!['price'], 95.0);
      expect(_find(parsed, 'rice')!['price'], 650.0);
    });

    test('strips trailing product codes from the name', () {
      final milk = _find(parsed, 'milk')!;
      expect(milk['name'], isNot(contains('50561')));
    });

    test('skips invoice and BIN metadata', () {
      final names = _names(parsed).join(' ');
      expect(names, isNot(contains('bin')));
      expect(names, isNot(contains('invoice')));
      expect(names, isNot(contains('net payable')));
    });
  });

  group('Strategy 3 — two-column OCR', () {
    final parsed = GroceryOcrParser.parseReceipt(kReceiptColumnSplit);

    test('pairs the name block with the price block in order', () {
      expect(parsed, isNotEmpty);
      expect(_find(parsed, 'yogurt'), isNotNull);
      expect(_find(parsed, 'spinach'), isNotNull);
    });

    test('excludes the store header from the name block', () {
      expect(_find(parsed, 'value foods'), isNull);
      expect(_find(parsed, 'store'), isNull);
    });
  });

  group('Freetext fallback', () {
    final parsed = GroceryOcrParser.parseReceipt(kFreeTextList);

    test('recognises a plain grocery list with no prices', () {
      expect(_names(parsed), containsAll(['milk', 'eggs', 'spinach']));
    });

    test('leaves price null when the list has none', () {
      expect(_find(parsed, 'milk')!['price'], isNull);
    });

    test('still filters non-food entries', () {
      expect(_find(parsed, 'shampoo'), isNull);
    });

    test('title-cases the names', () {
      final raw = GroceryOcrParser.parseReceipt('milk\neggs\nspinach');
      expect(raw.map((i) => i['name']), contains('Milk'));
    });
  });

  group('Robustness', () {
    test('empty input yields no items', () {
      expect(GroceryOcrParser.parseReceipt(''), isEmpty);
    });

    test('whitespace-only input yields no items', () {
      expect(GroceryOcrParser.parseReceipt('   \n\n  \t '), isEmpty);
    });

    test('a receipt with no food yields no items', () {
      expect(GroceryOcrParser.parseReceipt(kNonFoodText), isEmpty);
    });

    test('never returns more than 30 items', () {
      final many =
          List.generate(60, (i) => 'Milk Carton $i 2.50').join('\n');
      expect(GroceryOcrParser.parseReceipt(many).length, lessThanOrEqualTo(30));
    });

    test('discards refund and discount lines', () {
      final parsed = GroceryOcrParser.parseReceipt(
          'FRESH MART\nMilk 2.50\nCoupon Milk -1.00\nTOTAL 1.50');
      final prices = parsed.map((i) => i['price'] as double);
      expect(prices.every((p) => p > 0), isTrue);
    });

    test('rejects prices below the 10-cent floor', () {
      final parsed = GroceryOcrParser.parseReceipt('Milk 0.05\nBread 2.00');
      expect(_find(parsed, 'milk'), isNull);
      expect(_find(parsed, 'bread'), isNotNull);
    });

    test('handles comma decimal separators', () {
      final parsed = GroceryOcrParser.parseReceipt('EDEKA\nMilch 1,99\nBrot 2,49');
      expect(parsed.any((i) => i['price'] == 1.99), isTrue);
    });

    test('does not crash on very long single-line input', () {
      final long = 'Milk ${'x' * 5000} 2.50';
      expect(() => GroceryOcrParser.parseReceipt(long), returnsNormally);
    });

    test('is deterministic across repeated runs', () {
      final a = GroceryOcrParser.parseReceipt(kReceiptSameLine);
      final b = GroceryOcrParser.parseReceipt(kReceiptSameLine);
      expect(_names(a), _names(b));
    });
  });

  group('All-caps receipts', () {
    // Most supermarket receipts print item names in capitals, so this is the
    // mainstream layout rather than an edge case.
    final parsed = GroceryOcrParser.parseReceipt(
      'FRESH MART\nWHOLE MILK 3.49\nBROWN RICE 2.10\nFRESH EGGS 4.29',
    );

    test('keeps the food word in the name', () {
      expect(_names(parsed), containsAll(['whole milk', 'brown rice', 'fresh eggs']));
    });

    test('still categorises the item correctly', () {
      expect(_find(parsed, 'milk')?['category'], FoodCategory.dairy);
      expect(_find(parsed, 'rice')?['category'], FoodCategory.grains);
      expect(_find(parsed, 'egg')?['category'], FoodCategory.eggs);
    });

    test('assigns the category shelf life, not the generic 14-day default', () {
      // Milk keeps for ~7 days, eggs ~21 — a flat 14 misleads in both directions.
      expect(_find(parsed, 'milk')?['estimatedExpiryDays'], 7);
      expect(_find(parsed, 'egg')?['estimatedExpiryDays'], 21);
    });
  });

  group('Price sanity (offline fallback quality)', () {
    test('a single-item scan does not inherit the basket total as its price', () {
      // Mirrors the reported "Chicken Breast · $52.79" offline result: the
      // only food line has no price of its own, but the receipt total does.
      final parsed = GroceryOcrParser.parseReceipt(
        'SUPER SHOP\nChicken Breast\nSUBTOTAL\n52.79\nTOTAL\n52.79',
      );
      final chicken = _find(parsed, 'chicken');
      if (chicken != null) {
        expect(chicken['price'], isNot(52.79),
            reason: 'the receipt total must not be attached as an item price');
      }
    });
  });
}
