// ignore_for_file: avoid_print
// Diagnostic probe for GroceryOcrParser — prints what each receipt layout
// actually yields. Run with: dart run tool/ocr_probe.dart
import 'package:pantrypal/core/utils/grocery_ocr_parser.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

const cases = <String, String>{
  'all-caps names (South Asian numbered)': '''
SL Description Qty MRP Amount
1. FRESH MILK 1LTR 50561
8901234567 1 95 95
2. BASMATI RICE 5KG 50534
8901234568 1 650 650
''',
  'all-caps same-line': '''
FRESH MART
WHOLE MILK 3.49
BROWN RICE 2.10
FRESH EGGS 4.29
''',
  'column split (names then prices)': '''
VALUE FOODS
Greek Yogurt
Spinach
Salmon Fillet
5.25
2.10
12.40
TOTAL
19.75
''',
  'single item + basket total (screenshot case)': '''
SUPER SHOP
Chicken Breast
SUBTOTAL
52.79
TOTAL
52.79
''',
};

void main() {
  for (final e in cases.entries) {
    print('\n=== ${e.key} ===');
    final parsed = GroceryOcrParser.parseReceipt(e.value);
    if (parsed.isEmpty) print('  (no items)');
    for (final i in parsed) {
      print('  name="${i['name']}"  price=${i['price']}  '
          'cat=${(i['category'] as FoodCategory).name}  shelf=${i['estimatedExpiryDays']}d');
    }
  }
}
