import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/domain/services/pantry_insights.dart';

import '../support/fixtures.dart';

void main() {
  group('calendar-day expiry', () {
    test('an item added today with N days reads N days, not N-1', () {
      final added = PantryItem(
        id: 'x',
        name: 'Milk',
        category: FoodCategory.dairy,
        location: StorageLocation.fridge,
        quantity: 1,
        unit: 'item',
        expiryDate: PantryItem.expiryInDays(3),
        addedDate: DateTime.now(),
        isConsumed: false,
        isWasted: false,
      );
      expect(added.daysUntilExpiry, 3);
      expect(added.expiryLabel, 'Expires in 3 days');
    });

    test('an item expiring today is not yet expired', () {
      expect(item(daysFromNow: 0).expiryStatus, ExpiryStatus.expiringSoon);
    });

    test('an item expiring late tonight still reads "today" this morning', () {
      final tonight = item().copyWith(
        expiryDate: DateTime.now().copyWith(hour: 23, minute: 59),
      );
      expect(tonight.daysUntilExpiry, 0);
      expect(tonight.expiryStatus, ExpiryStatus.expiringSoon);
    });

    test('yesterday is expired', () {
      expect(item(daysFromNow: -1).expiryStatus, ExpiryStatus.expired);
      expect(item(daysFromNow: -1).daysUntilExpiry, -1);
    });
  });

  group('useFirst', () {
    test('includes expired and next-3-days items, most urgent first', () {
      final items = [
        item(name: 'Later', daysFromNow: 10),
        item(name: 'Soon', daysFromNow: 2),
        item(name: 'Old', daysFromNow: -2),
        item(name: 'Today', daysFromNow: 0),
      ];
      expect(PantryInsights.useFirst(items).map((i) => i.name), ['Old', 'Today', 'Soon']);
    });

    test('skips consumed and wasted items', () {
      final items = [
        item(name: 'Eaten', daysFromNow: 1, isConsumed: true),
        item(name: 'Binned', daysFromNow: 1, isWasted: true),
      ];
      expect(PantryInsights.useFirst(items), isEmpty);
    });
  });

  group('atRiskValue', () {
    test('sums real prices and category estimates for food still good', () {
      final items = [
        item(name: 'Milk', daysFromNow: 1, price: 4.0),
        item(name: 'Yogurt', daysFromNow: 2), // dairy estimate 3.5
        item(name: 'Old', daysFromNow: -1, price: 100), // already expired: not "at risk"
        item(name: 'Later', daysFromNow: 9, price: 50),
      ];
      expect(PantryInsights.atRiskValue(items), closeTo(7.5, 0.001));
    });
  });

  group('estimated value', () {
    test('prefers the real price and flags estimates', () {
      final priced = item(price: 6.2);
      expect(priced.estimatedValue, 6.2);
      expect(priced.isValueEstimated, isFalse);

      final unpriced = item(category: FoodCategory.meat);
      expect(unpriced.estimatedValue, FoodCategory.meat.averagePrice);
      expect(unpriced.isValueEstimated, isTrue);
    });
  });

  group('money', () {
    test('formats whole and fractional amounts', () {
      expect(PantryInsights.money(8), r'$8');
      expect(PantryInsights.money(7.5), r'$7.50');
      expect(PantryInsights.money(24.4, approx: true), r'~$24');
    });
  });

  group('shortWhen', () {
    test('reads naturally', () {
      expect(PantryInsights.shortWhen(item(daysFromNow: 0)), 'Today');
      expect(PantryInsights.shortWhen(item(daysFromNow: 1)), 'Tomorrow');
      expect(PantryInsights.shortWhen(item(daysFromNow: 4)), 'In 4 days');
      expect(PantryInsights.shortWhen(item(daysFromNow: -1)), 'Expired yesterday');
      expect(PantryInsights.shortWhen(item(daysFromNow: -3)), 'Expired 3 days ago');
    });
  });

  group('default storage', () {
    test('food goes where it normally lives', () {
      expect(FoodCategory.dairy.defaultLocation, StorageLocation.fridge);
      expect(FoodCategory.grains.defaultLocation, StorageLocation.pantry);
      expect(FoodCategory.frozen.defaultLocation, StorageLocation.freezer);
    });
  });
}
