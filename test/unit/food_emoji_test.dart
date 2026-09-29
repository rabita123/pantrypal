import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/utils/food_emoji.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

void main() {
  group('Specific matches beat the category fallback', () {
    test('maps common staples to their own emoji', () {
      expect(foodEmoji('Whole Milk', FoodCategory.dairy), '🥛');
      expect(foodEmoji('Cheddar Cheese', FoodCategory.dairy), '🧀');
      expect(foodEmoji('Sourdough Bread', FoodCategory.grains), '🍞');
      expect(foodEmoji('Basmati Rice', FoodCategory.grains), '🍚');
    });

    test('dish names win over their ingredients', () {
      // "Banana Oat Porridge" should read as a bowl, not a banana.
      expect(foodEmoji('Banana Oat Porridge', FoodCategory.grains), '🥣');
      expect(foodEmoji('Chicken Curry', FoodCategory.meat), '🍛');
      expect(foodEmoji('Tomato Soup', FoodCategory.condiments), '🍲');
    });

    test('is case and whitespace insensitive', () {
      expect(foodEmoji('  WHOLE MILK  ', FoodCategory.dairy),
          foodEmoji('whole milk', FoodCategory.dairy));
    });
  });

  group('Fallback behaviour', () {
    test('unknown names fall back to the category emoji', () {
      expect(foodEmoji('Zorbium Flakes', FoodCategory.other),
          FoodCategory.other.emoji);
      expect(foodEmoji('qqqq', FoodCategory.beverages),
          FoodCategory.beverages.emoji);
    });

    test('an empty name still returns the category emoji', () {
      expect(foodEmoji('', FoodCategory.dairy), FoodCategory.dairy.emoji);
    });

    test('never returns an empty string for any category', () {
      for (final c in FoodCategory.values) {
        expect(foodEmoji('unmatched-name-xyz', c), isNotEmpty);
      }
    });
  });
}
