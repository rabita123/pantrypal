// Exercises the real SQLite schema and queries via sqflite's FFI backend,
// so CRUD, filtering and the stats aggregation are tested against actual SQL
// rather than a stubbed repository.

import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

import '../support/test_db.dart';
import '../support/fixtures.dart';

void main() {
  late DatabaseHelper db;

  setUpAll(() async {
    await initTestDatabase('database_helper');

  });

  setUp(() async {
    db = DatabaseHelper.instance;
    await db.clearAllData();
  });

  group('Schema', () {
    test('creates both tables with the expected columns', () async {
      final raw = await db.database;
      final itemCols = (await raw.rawQuery(
              'PRAGMA table_info(${AppConstants.itemsTable})'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(
        itemCols,
        containsAll(<String>[
          'id', 'name', 'category', 'location', 'quantity', 'unit',
          'expiry_date', 'added_date', 'price', 'barcode', 'image_url',
          'notes', 'is_consumed', 'is_wasted', 'resolved_at',
        ]),
      );

      final shopCols = (await raw.rawQuery(
              'PRAGMA table_info(${AppConstants.shoppingTable})'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(
        shopCols,
        containsAll(<String>[
          'id', 'name', 'category', 'quantity', 'unit', 'is_checked',
          'added_date', 'notes',
        ]),
      );
    });
  });

  group('Pantry CRUD', () {
    test('inserts and reads an item back intact', () async {
      final milk = item(
        name: 'Whole Milk',
        category: FoodCategory.dairy,
        location: StorageLocation.fridge,
        quantity: 2,
        unit: 'L',
        price: 3.49,
      );
      await db.insertItem(milk);

      final all = await db.getAllActiveItems();
      expect(all.length, 1);
      final read = all.single;
      expect(read.id, milk.id);
      expect(read.name, 'Whole Milk');
      expect(read.category, FoodCategory.dairy);
      expect(read.location, StorageLocation.fridge);
      expect(read.quantity, 2);
      expect(read.unit, 'L');
      expect(read.price, 3.49);
    });

    test('preserves the expiry timestamp to the second', () async {
      final i = item(daysFromNow: 5);
      await db.insertItem(i);
      final read = (await db.getAllActiveItems()).single;
      expect(
        read.expiryDate.millisecondsSinceEpoch,
        i.expiryDate.millisecondsSinceEpoch,
      );
    });

    test('inserting the same id twice replaces rather than duplicates', () async {
      final i = item(name: 'Milk');
      await db.insertItem(i);
      await db.insertItem(i.copyWith(name: 'Oat Milk'));

      final all = await db.getAllActiveItems();
      expect(all.length, 1);
      expect(all.single.name, 'Oat Milk');
    });

    test('updates an existing item', () async {
      final i = item(name: 'Milk', quantity: 1);
      await db.insertItem(i);
      await db.updateItem(i.copyWith(quantity: 5, notes: 'half used'));

      final read = (await db.getAllActiveItems()).single;
      expect(read.quantity, 5);
      expect(read.notes, 'half used');
    });

    test('deletes an item', () async {
      final i = item();
      await db.insertItem(i);
      await db.deleteItem(i.id);
      expect(await db.getAllActiveItems(), isEmpty);
    });

    test('orders active items by soonest expiry', () async {
      await db.insertItem(item(name: 'Late', daysFromNow: 30));
      await db.insertItem(item(name: 'Soon', daysFromNow: 1));
      await db.insertItem(item(name: 'Mid', daysFromNow: 10));

      final names = (await db.getAllActiveItems()).map((i) => i.name).toList();
      expect(names, ['Soon', 'Mid', 'Late']);
    });

    test('preserves a null price', () async {
      await db.insertItem(item(price: null));
      expect((await db.getAllActiveItems()).single.price, isNull);
    });
  });

  group('Consumed and wasted', () {
    test('marking consumed removes the item from the active list', () async {
      final i = item();
      await db.insertItem(i);
      await db.markConsumed(i.id);
      expect(await db.getAllActiveItems(), isEmpty);
    });

    test('marking wasted removes the item from the active list', () async {
      final i = item();
      await db.insertItem(i);
      await db.markWasted(i.id);
      expect(await db.getAllActiveItems(), isEmpty);
    });
  });

  group('Filtering', () {
    test('filters by storage location', () async {
      await db.insertItem(item(name: 'Fridge Milk', location: StorageLocation.fridge));
      await db.insertItem(item(name: 'Pantry Rice', location: StorageLocation.pantry));

      final fridge = await db.getItemsByLocation('fridge');
      expect(fridge.map((i) => i.name), ['Fridge Milk']);
    });

    test('expiring window excludes already-expired and far-future items', () async {
      await db.insertItem(item(name: 'Expired', daysFromNow: -3));
      await db.insertItem(item(name: 'Soon', daysFromNow: 2));
      await db.insertItem(item(name: 'Later', daysFromNow: 40));

      final expiring = await db.getExpiringItems(withinDays: 7);
      expect(expiring.map((i) => i.name), ['Soon']);
    });

    test('search is a case-insensitive substring match', () async {
      await db.insertItem(item(name: 'Greek Yogurt'));
      await db.insertItem(item(name: 'Chicken Breast'));

      expect((await db.searchItems('yog')).map((i) => i.name), ['Greek Yogurt']);
      expect((await db.searchItems('YOG')).map((i) => i.name), ['Greek Yogurt']);
      expect(await db.searchItems('zzz'), isEmpty);
    });

    test('search excludes consumed items', () async {
      final i = item(name: 'Greek Yogurt');
      await db.insertItem(i);
      await db.markConsumed(i.id);
      expect(await db.searchItems('yog'), isEmpty);
    });
  });

  group('Stats aggregation', () {
    test('counts each bucket correctly', () async {
      await db.insertItem(item(name: 'Fresh', daysFromNow: 30));
      await db.insertItem(item(name: 'Soon', daysFromNow: 2));
      await db.insertItem(item(name: 'Expired', daysFromNow: -2));

      final consumed = item(name: 'Eaten');
      await db.insertItem(consumed);
      await db.markConsumed(consumed.id);

      final wasted = item(name: 'Binned', price: 4.25);
      await db.insertItem(wasted);
      await db.markWasted(wasted.id);

      final stats = await db.getStats();
      expect(stats['total'], 3, reason: 'active items only');
      expect(stats['expiringSoon'], 1);
      expect(stats['expired'], 1);
      expect(stats['consumed'], 1);
      expect(stats['wasted'], 1);
      expect(stats['wastedValue'], 4.25);
    });

    test('sums wasted value across several items', () async {
      for (final price in [2.50, 3.25, 1.00]) {
        final i = item(price: price);
        await db.insertItem(i);
        await db.markWasted(i.id);
      }
      final stats = await db.getStats();
      expect(stats['wastedValue'], closeTo(6.75, 0.001));
    });

    test('wasted value is 0.0 not null when nothing is wasted', () async {
      final stats = await db.getStats();
      expect(stats['wastedValue'], 0.0);
    });

    test('wasted items with no price contribute nothing', () async {
      final i = item(price: null);
      await db.insertItem(i);
      await db.markWasted(i.id);

      final stats = await db.getStats();
      expect(stats['wasted'], 1);
      expect(stats['wastedValue'], 0.0);
    });

    test('empty database returns all-zero stats', () async {
      final stats = await db.getStats();
      expect(stats['total'], 0);
      expect(stats['expiringSoon'], 0);
      expect(stats['expired'], 0);
      expect(stats['consumed'], 0);
      expect(stats['wasted'], 0);
    });
  });

  group('Shopping list', () {
    test('inserts and reads a shopping item', () async {
      await db.insertShoppingItem(shoppingItem(name: 'Bread'));
      final all = await db.getAllShoppingItems();
      expect(all.single.name, 'Bread');
      expect(all.single.isChecked, isFalse);
    });

    test('toggles checked state', () async {
      final s = shoppingItem();
      await db.insertShoppingItem(s);
      await db.toggleShoppingItem(s.id, true);
      expect((await db.getAllShoppingItems()).single.isChecked, isTrue);

      await db.toggleShoppingItem(s.id, false);
      expect((await db.getAllShoppingItems()).single.isChecked, isFalse);
    });

    test('sorts unchecked items before checked ones', () async {
      final done = shoppingItem(name: 'Done');
      await db.insertShoppingItem(done);
      await db.insertShoppingItem(shoppingItem(name: 'Todo'));
      await db.toggleShoppingItem(done.id, true);

      final names = (await db.getAllShoppingItems()).map((i) => i.name).toList();
      expect(names.first, 'Todo');
    });

    test('clearing done removes only the checked items', () async {
      final done = shoppingItem(name: 'Done');
      await db.insertShoppingItem(done);
      await db.insertShoppingItem(shoppingItem(name: 'Todo'));
      await db.toggleShoppingItem(done.id, true);

      await db.clearCheckedShoppingItems();
      final names = (await db.getAllShoppingItems()).map((i) => i.name).toList();
      expect(names, ['Todo']);
    });

    test('deletes a shopping item', () async {
      final s = shoppingItem();
      await db.insertShoppingItem(s);
      await db.deleteShoppingItem(s.id);
      expect(await db.getAllShoppingItems(), isEmpty);
    });
  });

  group('Clear all data', () {
    test('empties both tables', () async {
      await db.insertItem(item());
      await db.insertShoppingItem(shoppingItem());
      await db.clearAllData();

      expect(await db.getAllActiveItems(), isEmpty);
      expect(await db.getAllShoppingItems(), isEmpty);
    });
  });

  group('Monthly outcomes', () {
    test('counts and values this month\'s used and tossed food', () async {
      final used = item(name: 'Spinach', category: FoodCategory.vegetables, price: 2.0);
      final usedNoPrice = item(name: 'Yogurt', category: FoodCategory.dairy); // est 3.5
      final tossed = item(name: 'Chicken', category: FoodCategory.meat); // est 8.0
      for (final i in [used, usedNoPrice, tossed]) {
        await db.insertItem(i);
      }
      await db.markConsumed(used.id);
      await db.markConsumed(usedNoPrice.id);
      await db.markWasted(tossed.id);

      final stats = await db.getStats();
      expect(stats['consumedMonth'], 2);
      expect(stats['wastedMonth'], 1);
      expect(stats['savedValueMonth'], closeTo(5.5, 0.001));
      expect(stats['wastedValueMonth'], closeTo(8.0, 0.001));
    });

    test('food resolved before this month is not counted as this month', () async {
      final old = item(name: 'Old', price: 9.0);
      await db.insertItem(old);
      await db.markConsumed(old.id);
      final raw = await db.database;
      final lastMonth = DateTime.now().subtract(const Duration(days: 45)).millisecondsSinceEpoch;
      await raw.update(AppConstants.itemsTable, {'resolved_at': lastMonth},
          where: 'id = ?', whereArgs: [old.id]);

      final stats = await db.getStats();
      expect(stats['consumedMonth'], 0);
      expect(stats['consumed'], 1, reason: 'still counted in the all-time total');
    });

    test('recently consumed lists newest first and ignores old ones', () async {
      final a = item(name: 'A');
      final b = item(name: 'B');
      await db.insertItem(a);
      await db.insertItem(b);
      await db.markConsumed(a.id);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await db.markConsumed(b.id);

      final recent = await db.getRecentlyConsumed();
      expect(recent.map((i) => i.name), ['B', 'A']);
    });
  });
}
