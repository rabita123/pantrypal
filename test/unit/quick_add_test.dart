import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/constants/starter_foods.dart';
import 'package:pantrypal/core/utils/quick_add.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

void main() {
  group('splitNames', () {
    test('splits on commas, "and", ampersands and new lines', () {
      expect(
        QuickAdd.splitNames('milk, eggs and spinach & bread\nrice'),
        ['milk', 'eggs', 'spinach', 'bread', 'rice'],
      );
    });

    test('ignores empty pieces', () {
      expect(QuickAdd.splitNames(' , milk,, '), ['milk']);
      expect(QuickAdd.splitNames('   '), isEmpty);
    });

    test('does not split inside a word containing "and"', () {
      expect(QuickAdd.splitNames('sandwich, candy'), ['sandwich', 'candy']);
    });
  });

  group('parseLine', () {
    test('reads a leading quantity', () {
      expect(QuickAdd.parseLine('2 eggs'), (quantity: 2.0, name: 'eggs'));
      expect(QuickAdd.parseLine('3x apples'), (quantity: 3.0, name: 'apples'));
    });

    test('a bare name is quantity 1', () {
      expect(QuickAdd.parseLine('milk'), (quantity: 1.0, name: 'milk'));
    });

    test('a digit glued to letters stays part of the name', () {
      expect(QuickAdd.parseLine('7up').name, '7up');
    });
  });

  group('parse', () {
    final now = DateTime(2026, 3, 10, 15, 30);

    test('known foods use their realistic shelf life and home', () {
      final items = QuickAdd.parse('spinach, rice, bananas', now: now);
      final byName = {for (final i in items) i.name: i};

      expect(byName['Spinach']!.daysUntilExpiryFrom(now), 4);
      expect(byName['Spinach']!.location, StorageLocation.fridge);
      expect(byName['Rice']!.location, StorageLocation.pantry);
      expect(byName['Rice']!.daysUntilExpiryFrom(now), 365);
      expect(byName['Bananas']!.location, StorageLocation.counter);
    });

    test('unknown foods fall back to category defaults', () {
      final item = QuickAdd.parse('cheddar', now: now).single;
      expect(item.category, FoodCategory.dairy);
      expect(item.location, StorageLocation.fridge);
      expect(item.daysUntilExpiryFrom(now), 7);
    });

    test('titles the name and keeps the quantity', () {
      final item = QuickAdd.parse('2 greek yogurt', now: now).single;
      expect(item.name, 'Greek Yogurt');
      expect(item.quantity, 2);
    });

    test('every item gets a unique id and is active', () {
      final items = QuickAdd.parse('milk, milk, milk');
      expect(items.map((i) => i.id).toSet().length, 3);
      expect(items.every((i) => i.isActive), isTrue);
    });
  });

  group('starter foods', () {
    test('lookup tolerates case and plurals', () {
      expect(starterFoodFor('TOMATO')?.name, 'Tomatoes');
      expect(starterFoodFor('egg')?.name, 'Eggs');
    });

    test('every starter food has a positive shelf life', () {
      expect(starterFoods.every((f) => f.shelfDays > 0), isTrue);
    });
  });
}

extension on PantryItem {
  /// Calendar days from [from] to expiry, for tests pinned to a fixed clock.
  int daysUntilExpiryFrom(DateTime from) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(expiryDate.year, expiryDate.month, expiryDate.day);
    return b.difference(a).inDays;
  }
}
