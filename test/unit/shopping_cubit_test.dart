import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/shopping_cubit.dart';

import '../support/fixtures.dart';
import '../support/plugin_stubs.dart';
import '../support/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShoppingCubit cubit;

  setUpAll(() async {
    await initTestDatabase('shopping_cubit');
    stubNotificationPlugin();
    stubHomeWidgetPlugin();
    stubSharedPreferences();
  });

  setUp(() async {
    await DatabaseHelper.instance.clearAllData();
    cubit = ShoppingCubit(PantryRepository());
  });

  tearDown(() => cubit.close());

  test('starts unloaded, then loads an empty list', () async {
    expect(cubit.state.loaded, isFalse);
    await cubit.load();
    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.items, isEmpty);
  });

  test('adds, toggles and clears done items', () async {
    await cubit.add(shoppingItem(id: 's1', name: 'Bread'));
    await cubit.add(shoppingItem(id: 's2', name: 'Butter'));
    await cubit.toggle('s1', true);
    await cubit.clearDone();
    expect(cubit.state.items.map((i) => i.name), ['Butter']);
  });

  test('deletes an item', () async {
    await cubit.add(shoppingItem(id: 's9', name: 'Jam'));
    await cubit.delete('s9');
    expect(cubit.state.items, isEmpty);
  });

  test('addNames skips blanks and names already on the list', () async {
    await cubit.add(shoppingItem(id: 'a', name: 'Flour'));
    final added = await cubit.addNames(['flour', 'Eggs', '  ', 'Eggs']);
    expect(added, 1, reason: 'only Eggs is new');
    expect(cubit.state.items.map((i) => i.name).toSet(), {'Flour', 'Eggs'});
  });

  test('touching the list never disturbs the pantry state', () async {
    final pantry = PantryBloc(PantryRepository());
    pantry.add(PantryLoad());
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final before = pantry.state;

    await cubit.add(shoppingItem(name: 'Rice'));

    expect(pantry.state, same(before));
    expect(pantry.state, isA<PantryLoaded>());
    await pantry.close();
  });
}
