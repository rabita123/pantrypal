// Shopping list is fully local (no camera, no network), so the whole page can
// be driven in a widget test against a real repository over in-memory SQLite.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/shopping_cubit.dart';
import 'package:pantrypal/features/recipes/data/repositories/recipe_repository.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/plan/data/plan_repository.dart';
import 'package:pantrypal/features/plan/presentation/plan_cubit.dart';
import 'package:pantrypal/features/pantry/presentation/pages/shopping_page.dart';

import '../support/di.dart';
import '../support/fixtures.dart';
import '../support/test_db.dart';
import '../support/plugin_stubs.dart';

/// Pumps the page and lets the real SQLite I/O behind `ShoppingLoad` finish.
///
/// `pumpAndSettle` alone is not enough here: sqflite's FFI backend does genuine
/// asynchronous work that the test's fake-async zone will not advance, so the
/// cubit never finishes loading.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
}

Future<void> pumpShopping(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      // ShoppingPage renders inside DashboardPage's Scaffold in the real app,
      // so it needs a Material ancestor supplied here.
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => PantryBloc(PantryRepository())),
            BlocProvider(create: (_) => ShoppingCubit(PantryRepository())),
            BlocProvider(create: (_) => RecipeBloc(RecipeRepository())),
            BlocProvider(create: (_) => PlanCubit(PlanRepository(), PantryRepository())..load()),
          ],
          child: const ShoppingPage(),
        ),
      ),
    ),
  );
  await settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestDatabase('shopping_page');
    stubNotificationPlugin();
    stubHomeWidgetPlugin();
    stubSharedPreferences();
  });

  setUp(() async {
    await registerTestDependencies();
    await DatabaseHelper.instance.clearAllData();
  });

  tearDown(resetTestDependencies);

  testWidgets('shows an empty state on first open', (tester) async {
    await pumpShopping(tester);
    expect(find.text('List is empty'), findsOneWidget);
  });

  testWidgets('adds a typed item to the list', (tester) async {
    await pumpShopping(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Add item...'), 'Olive Oil');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await settle(tester);

    expect(find.text('Olive Oil'), findsOneWidget);
    expect(find.text('List is empty'), findsNothing);
  });

  testWidgets('persists the item across a rebuild', (tester) async {
    await pumpShopping(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Add item...'), 'Olive Oil');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await settle(tester);

    await pumpShopping(tester);
    expect(find.text('Olive Oil'), findsOneWidget);
  });

  testWidgets('does not add a blank item', (tester) async {
    await pumpShopping(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await settle(tester);
    expect(find.text('List is empty'), findsOneWidget);
  });

  testWidgets('checking an item then clearing done empties the list',
      (tester) async {
    await pumpShopping(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Add item...'), 'Olive Oil');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await settle(tester);

    // The list row exposes a trailing Checkbox — that is the tick affordance.
    await tester.tap(find.byType(Checkbox));
    await settle(tester);

    expect(find.text('Clear done'), findsOneWidget,
        reason: '"Clear done" appears once something is ticked');
    expect(find.text('Add to pantry'), findsOneWidget,
        reason: 'ticked items can go straight into the pantry');

    await tester.tap(find.text('Clear done'));
    await settle(tester);

    expect(find.text('Olive Oil'), findsNothing);
    expect(find.text('List is empty'), findsOneWidget);
  });

  pantryAwareTests();
}

// Appended: behaviours specific to the pantry-aware list.
void pantryAwareTests() {
  testWidgets('warns before buying something already in the pantry', (tester) async {
    await tester.runAsync(() => DatabaseHelper.instance.insertItem(item(name: 'Milk')));
    await pumpShopping(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Add item...'), 'Milk');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await settle(tester);

    expect(find.text('You already have Milk'), findsOneWidget);

    await tester.tap(find.text('Skip it'));
    await settle(tester);
    expect(find.text('List is empty'), findsOneWidget, reason: 'skipping adds nothing');
  });

  testWidgets('"Add anyway" still adds the item', (tester) async {
    await tester.runAsync(() => DatabaseHelper.instance.insertItem(item(name: 'Milk')));
    await pumpShopping(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Add item...'), 'Milk');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await settle(tester);
    await tester.tap(find.text('Add anyway'));
    await settle(tester);

    expect(find.text('Milk'), findsOneWidget);
  });

  testWidgets('moving bought items adds them to the pantry and clears the list',
      (tester) async {
    await pumpShopping(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Add item...'), 'Spinach');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await settle(tester);
    await tester.tap(find.byType(Checkbox));
    await settle(tester);

    await tester.tap(find.text('Add to pantry'));
    await settle(tester);

    final pantry = await tester.runAsync(() => DatabaseHelper.instance.getAllActiveItems());
    expect(pantry!.map((i) => i.name), contains('Spinach'));
    expect(find.text('List is empty'), findsOneWidget);
  });
}
