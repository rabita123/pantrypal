import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:pantrypal/features/dashboard/presentation/pages/home_tab.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/widgets/add_food_sheet.dart';
import 'package:pantrypal/features/plan/data/plan_repository.dart';
import 'package:pantrypal/features/plan/presentation/plan_cubit.dart';
import 'package:pantrypal/features/recipes/data/repositories/recipe_repository.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';

import '../support/di.dart';
import '../support/fixtures.dart';
import '../support/plugin_stubs.dart';
import '../support/test_db.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
}

Future<void> pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => PantryBloc(PantryRepository())..add(PantryLoad())),
          BlocProvider(create: (_) => RecipeBloc(RecipeRepository())..add(RecipeLoad())),
          BlocProvider(create: (_) => PlanCubit(PlanRepository(), PantryRepository())..load()),
        ],
        child: HomeTab(onOpenPantry: () {}),
      ),
    ),
  ));
  await settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestDatabase('home_and_add');
    stubNotificationPlugin();
    stubHomeWidgetPlugin();
    stubSharedPreferences();
  });

  setUp(() async {
    await registerTestDependencies();
    await DatabaseHelper.instance.clearAllData();
  });

  tearDown(resetTestDependencies);

  testWidgets('empty home leads with the receipt scan, not a stats grid', (tester) async {
    await pumpHome(tester);
    expect(find.text('Scan a receipt'), findsOneWidget);
    expect(find.text('Tap what you have'), findsOneWidget);
    expect(find.text('Monthly Stats'), findsNothing);
  });

  testWidgets('shows money at risk and a one-tap Used / Toss for urgent food', (tester) async {
    await tester.runAsync(() async {
      await DatabaseHelper.instance.insertItem(item(name: 'Spinach', daysFromNow: 1, price: 4));
      await DatabaseHelper.instance.insertItem(item(name: 'Rice', daysFromNow: 200));
    });
    await pumpHome(tester);

    expect(find.textContaining(r'$4'), findsWidgets);
    expect(find.text('Use first'), findsOneWidget);
    expect(find.text('Spinach'), findsOneWidget);
    expect(find.text('Used'), findsOneWidget);
    expect(find.text('Toss'), findsOneWidget);
    expect(find.text('Rice'), findsNothing, reason: 'fresh food is not urgent');
  });

  testWidgets('marking food Used removes it and records the saving', (tester) async {
    await tester.runAsync(() => DatabaseHelper.instance.insertItem(item(name: 'Spinach', daysFromNow: 1, price: 4)));
    await pumpHome(tester);

    await tester.tap(find.text('Used'));
    await settle(tester);

    final stats = await tester.runAsync(() => DatabaseHelper.instance.getStats());
    expect(stats!['consumedMonth'], 1);
    expect(stats['savedValueMonth'], closeTo(4, 0.001));
  });

  testWidgets('add sheet offers every way in and returns the typed text', (tester) async {
    AddChoice? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await AddFoodSheet.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Scan a receipt'), findsOneWidget);
    expect(find.text('Fridge photo'), findsOneWidget);
    expect(find.text('Barcode'), findsOneWidget);
    expect(find.text('Tap foods'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'milk, eggs');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    expect(result?.kind, AddKind.typed);
    expect(result?.text, 'milk, eggs');
  });
}
