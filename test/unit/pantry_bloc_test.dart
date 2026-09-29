import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';

import '../support/test_db.dart';
import '../support/fixtures.dart';
import '../support/plugin_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PantryRepository repo;

  setUpAll(() async {
    await initTestDatabase('pantry_bloc');
    stubNotificationPlugin();
    stubHomeWidgetPlugin();
    stubSharedPreferences();
  });

  setUp(() async {
    await DatabaseHelper.instance.clearAllData();
    repo = PantryRepository();
  });

  group('Loading', () {
    blocTest<PantryBloc, PantryState>(
      'emits loading then loaded with stats',
      build: () => PantryBloc(repo),
      act: (bloc) => bloc.add(PantryLoad()),
      wait: const Duration(milliseconds: 300),
      expect: () => [isA<PantryLoading>(), isA<PantryLoaded>()],
      verify: (bloc) {
        final state = bloc.state as PantryLoaded;
        expect(state.items, isEmpty);
        expect(state.stats['total'], 0);
      },
    );

    blocTest<PantryBloc, PantryState>(
      'loaded state separates expiring items from all items',
      build: () => PantryBloc(repo),
      setUp: () async {
        await repo.addItem(item(name: 'Soon', daysFromNow: 2));
        await repo.addItem(item(name: 'Later', daysFromNow: 60));
      },
      act: (bloc) => bloc.add(PantryLoad()),
      wait: const Duration(milliseconds: 300),
      verify: (bloc) {
        final state = bloc.state as PantryLoaded;
        expect(state.items.length, 2);
        expect(state.expiringItems.map((i) => i.name), ['Soon']);
      },
    );
  });

  group('Adding items', () {
    blocTest<PantryBloc, PantryState>(
      'adding one item reloads with it present',
      build: () => PantryBloc(repo),
      act: (bloc) => bloc.add(PantryAddItem(item(name: 'Milk'))),
      wait: const Duration(milliseconds: 300),
      verify: (bloc) {
        final state = bloc.state as PantryLoaded;
        expect(state.items.map((i) => i.name), ['Milk']);
        expect(state.stats['total'], 1);
      },
    );

    blocTest<PantryBloc, PantryState>(
      'bulk add persists every item (scan-to-pantry path)',
      build: () => PantryBloc(repo),
      act: (bloc) => bloc.add(PantryAddItems([
        item(name: 'Milk'),
        item(name: 'Eggs'),
        item(name: 'Bread'),
      ])),
      wait: const Duration(milliseconds: 500),
      verify: (bloc) {
        expect((bloc.state as PantryLoaded).items.length, 3);
      },
    );
  });

  group('Item lifecycle', () {
    blocTest<PantryBloc, PantryState>(
      'marking consumed drops it from the list and bumps the stat',
      build: () => PantryBloc(repo),
      setUp: () async => repo.addItem(item(id: 'x1', name: 'Milk')),
      act: (bloc) async {
        bloc.add(PantryLoad());
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(PantryMarkConsumed('x1'));
      },
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        final state = bloc.state as PantryLoaded;
        expect(state.items, isEmpty);
        expect(state.stats['consumed'], 1);
      },
    );

    blocTest<PantryBloc, PantryState>(
      'marking wasted records the lost value',
      build: () => PantryBloc(repo),
      setUp: () async => repo.addItem(item(id: 'x2', name: 'Milk', price: 3.99)),
      act: (bloc) async {
        bloc.add(PantryLoad());
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(PantryMarkWasted('x2'));
      },
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        final state = bloc.state as PantryLoaded;
        expect(state.stats['wasted'], 1);
        expect(state.stats['wastedValue'], 3.99);
      },
    );

    blocTest<PantryBloc, PantryState>(
      'deleting removes the item entirely, not just from the active view',
      build: () => PantryBloc(repo),
      setUp: () async => repo.addItem(item(id: 'x3')),
      act: (bloc) async {
        bloc.add(PantryLoad());
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(PantryDeleteItem('x3'));
      },
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        final state = bloc.state as PantryLoaded;
        expect(state.items, isEmpty);
        expect(state.stats['consumed'], 0);
        expect(state.stats['wasted'], 0);
      },
    );

    blocTest<PantryBloc, PantryState>(
      'updating an item persists the change',
      build: () => PantryBloc(repo),
      setUp: () async => repo.addItem(item(id: 'x4', name: 'Milk')),
      act: (bloc) async {
        bloc.add(PantryLoad());
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(PantryUpdateItem(
            item(id: 'x4', name: 'Oat Milk', location: StorageLocation.freezer)));
      },
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        final state = bloc.state as PantryLoaded;
        expect(state.items.single.name, 'Oat Milk');
        expect(state.items.single.location, StorageLocation.freezer);
      },
    );
  });

  group('Search and filter', () {
    blocTest<PantryBloc, PantryState>(
      'search narrows items but keeps allItems intact',
      build: () => PantryBloc(repo),
      setUp: () async {
        await repo.addItem(item(name: 'Greek Yogurt'));
        await repo.addItem(item(name: 'Chicken Breast'));
      },
      act: (bloc) async {
        bloc.add(PantryLoad());
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(PantrySearch('yog'));
      },
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        final state = bloc.state as PantryLoaded;
        expect(state.items.map((i) => i.name), ['Greek Yogurt']);
        expect(state.allItems.length, 2);
        expect(state.searchQuery, 'yog');
      },
    );

    blocTest<PantryBloc, PantryState>(
      'clearing the search restores the full list',
      build: () => PantryBloc(repo),
      setUp: () async {
        await repo.addItem(item(name: 'Greek Yogurt'));
        await repo.addItem(item(name: 'Chicken Breast'));
      },
      act: (bloc) async {
        bloc.add(PantryLoad());
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(PantrySearch('yog'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(PantryClearSearch());
      },
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        final state = bloc.state as PantryLoaded;
        expect(state.items.length, 2);
        expect(state.searchQuery, '');
      },
    );

    blocTest<PantryBloc, PantryState>(
      'location filter narrows to that location and back',
      build: () => PantryBloc(repo),
      setUp: () async {
        await repo.addItem(item(name: 'Fridge Milk', location: StorageLocation.fridge));
        await repo.addItem(item(name: 'Pantry Rice', location: StorageLocation.pantry));
      },
      act: (bloc) async {
        bloc.add(PantryLoad());
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(PantryFilterByLocation(StorageLocation.fridge));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        final state = bloc.state as PantryLoaded;
        expect(state.items.map((i) => i.name), ['Fridge Milk']);
        expect(state.activeLocation, StorageLocation.fridge);
      },
    );

    blocTest<PantryBloc, PantryState>(
      'clearing the location filter restores everything',
      build: () => PantryBloc(repo),
      setUp: () async {
        await repo.addItem(item(location: StorageLocation.fridge));
        await repo.addItem(item(location: StorageLocation.pantry));
      },
      act: (bloc) async {
        bloc.add(PantryLoad());
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(PantryFilterByLocation(StorageLocation.fridge));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(PantryFilterByLocation(null));
      },
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        final state = bloc.state as PantryLoaded;
        expect(state.items.length, 2);
        expect(state.activeLocation, isNull);
      },
    );
  });
}
