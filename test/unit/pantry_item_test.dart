import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

import '../support/fixtures.dart';

void main() {
  group('PantryItem expiry status', () {
    test('fresh when more than 3 days remain', () {
      expect(item(daysFromNow: 10).expiryStatus, ExpiryStatus.fresh);
    });

    test('expiringSoon at the 3-day threshold', () {
      expect(item(daysFromNow: 3).expiryStatus, ExpiryStatus.expiringSoon);
      expect(item(daysFromNow: 1).expiryStatus, ExpiryStatus.expiringSoon);
      expect(item(daysFromNow: 0).expiryStatus, ExpiryStatus.expiringSoon);
    });

    test('expired once the date has passed', () {
      expect(item(daysFromNow: -1).expiryStatus, ExpiryStatus.expired);
    });
  });

  group('PantryItem labels', () {
    test('expiry label reads naturally across boundaries', () {
      expect(item(daysFromNow: 0).expiryLabel, 'Expires today!');
      expect(item(daysFromNow: 1).expiryLabel, 'Expires tomorrow');
      expect(item(daysFromNow: 5).expiryLabel, 'Expires in 5 days');
      expect(item(daysFromNow: -1).expiryLabel, 'Expired 1 day ago');
      expect(item(daysFromNow: -3).expiryLabel, 'Expired 3 days ago');
    });

    test('daysUntilExpiry is negative for expired items', () {
      expect(item(daysFromNow: -4).daysUntilExpiry, lessThan(0));
    });
  });

  group('PantryItem active flag', () {
    test('active only when neither consumed nor wasted', () {
      expect(item().isActive, isTrue);
      expect(item(isConsumed: true).isActive, isFalse);
      expect(item(isWasted: true).isActive, isFalse);
    });
  });

  group('PantryItem.copyWith', () {
    test('overrides the named field and preserves the rest', () {
      final original = item(name: 'Milk', quantity: 2, price: 3.5);
      final copy = original.copyWith(name: 'Oat Milk');

      expect(copy.name, 'Oat Milk');
      expect(copy.id, original.id);
      expect(copy.quantity, 2);
      expect(copy.price, 3.5);
      expect(copy.addedDate, original.addedDate);
    });

    test('cannot clear a nullable field back to null', () {
      // Documents the `??` copyWith idiom: passing null means "keep existing".
      final priced = item(price: 9.99);
      expect(priced.copyWith(price: null).price, 9.99);
    });

    test('marking consumed flips isActive', () {
      expect(item().copyWith(isConsumed: true).isActive, isFalse);
    });
  });

  group('Category and location parsing', () {
    test('round-trips every known enum name', () {
      for (final c in FoodCategory.values) {
        expect(FoodCategory.fromString(c.name), c);
      }
      for (final l in StorageLocation.values) {
        expect(StorageLocation.fromString(l.name), l);
      }
    });

    test('falls back on unknown input', () {
      expect(FoodCategory.fromString('nonsense'), FoodCategory.other);
      expect(StorageLocation.fromString('nonsense'), StorageLocation.pantry);
    });

    test('every category exposes a label and emoji', () {
      for (final c in FoodCategory.values) {
        expect(c.label, isNotEmpty);
        expect(c.emoji, isNotEmpty);
      }
    });
  });

  group('ShoppingItem', () {
    test('toggling checked preserves identity', () {
      final s = shoppingItem(name: 'Bread');
      final checked = s.copyWith(isChecked: true);
      expect(checked.isChecked, isTrue);
      expect(checked.id, s.id);
      expect(checked.name, 'Bread');
    });
  });
}
