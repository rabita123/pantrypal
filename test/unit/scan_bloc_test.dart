// Covers the scan pipeline's pure logic: the parsed-item → PantryItem
// conversion, selection toggling, inline edits, and the offline-fallback flag
// that drives the "results may be less accurate" banner.

// Selection sets are written as plain literals for readability.
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/scan/data/scan_bloc.dart';

Map<String, dynamic> parsed({
  String name = 'Milk',
  FoodCategory category = FoodCategory.dairy,
  double quantity = 1,
  String unit = 'item',
  double? price,
  int expiryDays = 7,
}) =>
    {
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'estimatedExpiryDays': expiryDays,
    };

void main() {
  group('buildPantryItems', () {
    late ScanBloc bloc;
    setUp(() => bloc = ScanBloc());
    tearDown(() => bloc.close());

    test('converts a parsed map into a persistable PantryItem', () {
      final state = ScanReviewReady([
        parsed(name: 'Whole Milk', quantity: 2, unit: 'L', price: 3.49, expiryDays: 7),
      ], {0});

      final built = bloc.buildPantryItems(state).single;
      expect(built.name, 'Whole Milk');
      expect(built.category, FoodCategory.dairy);
      expect(built.quantity, 2);
      expect(built.unit, 'L');
      expect(built.price, 3.49);
      expect(built.isConsumed, isFalse);
      expect(built.isWasted, isFalse);
      expect(built.id, isNotEmpty);
    });

    test('derives the expiry date from the estimated shelf life', () {
      final state = ScanReviewReady([parsed(expiryDays: 5)], {0});
      final built = bloc.buildPantryItems(state).single;
      expect(built.daysUntilExpiry, anyOf(4, 5));
    });

    test('only builds the selected items', () {
      final state = ScanReviewReady([
        parsed(name: 'Milk'),
        parsed(name: 'Eggs'),
        parsed(name: 'Bread'),
      ], {0, 2});

      final names = bloc.buildPantryItems(state).map((i) => i.name).toSet();
      expect(names, {'Milk', 'Bread'});
    });

    test('deselecting everything builds nothing', () {
      final state = ScanReviewReady([parsed()], <int>{});
      expect(bloc.buildPantryItems(state), isEmpty);
    });

    test('assigns unique ids across a batch', () {
      final state = ScanReviewReady(
        List.generate(5, (i) => parsed(name: 'Item $i')),
        {0, 1, 2, 3, 4},
      );
      final ids = bloc.buildPantryItems(state).map((i) => i.id).toSet();
      expect(ids.length, 5);
    });

    test('scanned items are filed where that food actually lives', () {
      final state = ScanReviewReady([
        parsed(),
        parsed(name: 'Rice', category: FoodCategory.grains),
        parsed(name: 'Peas', category: FoodCategory.frozen),
      ], {0, 1, 2});
      final locations = bloc.buildPantryItems(state).map((i) => i.location).toList();
      expect(locations, [StorageLocation.fridge, StorageLocation.pantry, StorageLocation.freezer]);
    });

    test('expiry is the calendar day the shelf life ends on', () {
      final state = ScanReviewReady([parsed(expiryDays: 3)], {0});
      expect(bloc.buildPantryItems(state).single.daysUntilExpiry, 3);
    });

    test('a null price survives as null', () {
      final state = ScanReviewReady([parsed(price: null)], {0});
      expect(bloc.buildPantryItems(state).single.price, isNull);
    });
  });

  group('Review interactions', () {
    test('toggling deselects then reselects an item', () async {
      final bloc = ScanBloc();
      bloc.emit(ScanReviewReady([parsed(), parsed(name: 'Eggs')], {0, 1}));

      bloc.add(ScanItemToggle(0));
      await Future<void>.delayed(Duration.zero);
      expect((bloc.state as ScanReviewReady).selectedIndices, {1});

      bloc.add(ScanItemToggle(0));
      await Future<void>.delayed(Duration.zero);
      expect((bloc.state as ScanReviewReady).selectedIndices, {0, 1});
      await bloc.close();
    });

    test('editing an item merges the change and keeps other fields', () async {
      final bloc = ScanBloc();
      bloc.emit(ScanReviewReady([parsed(name: 'Mlk', price: 3.49)], {0}));

      bloc.add(ScanUpdateItem(0, {'name': 'Milk'}));
      await Future<void>.delayed(Duration.zero);

      final items = (bloc.state as ScanReviewReady).parsedItems;
      expect(items.single['name'], 'Milk');
      expect(items.single['price'], 3.49);
      await bloc.close();
    });

    test('resetting returns to idle', () async {
      final bloc = ScanBloc();
      bloc.emit(ScanReviewReady([parsed()], {0}));
      bloc.add(ScanReset());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, isA<ScanIdle>());
      await bloc.close();
    });
  });

  group('Offline fallback banner', () {
    test('the flag is set when local OCR produced the results', () {
      final state = ScanReviewReady([parsed()], {0}, isOfflineFallback: true);
      expect(state.isOfflineFallback, isTrue);
    });

    test('toggling an item keeps the offline banner visible', () async {
      final bloc = ScanBloc();
      bloc.emit(ScanReviewReady(
          [parsed(), parsed(name: 'Eggs')], {0, 1}, isOfflineFallback: true));

      bloc.add(ScanItemToggle(1));
      await Future<void>.delayed(Duration.zero);

      expect((bloc.state as ScanReviewReady).isOfflineFallback, isTrue,
          reason: 'deselecting an item must not silently change the results '
              'from "offline, please check" to "verified by AI"');
      await bloc.close();
    });

    test('editing an item keeps the offline banner visible', () async {
      final bloc = ScanBloc();
      bloc.emit(ScanReviewReady([parsed()], {0}, isOfflineFallback: true));

      bloc.add(ScanUpdateItem(0, {'name': 'Milk'}));
      await Future<void>.delayed(Duration.zero);

      expect((bloc.state as ScanReviewReady).isOfflineFallback, isTrue);
      await bloc.close();
    });
  });
}
