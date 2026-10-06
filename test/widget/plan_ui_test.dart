import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/shopping_cubit.dart';
import 'package:pantrypal/features/plan/data/plan_repository.dart';
import 'package:pantrypal/features/plan/presentation/pages/batch_cook_page.dart';
import 'package:pantrypal/features/plan/presentation/pages/plan_tab.dart';
import 'package:pantrypal/features/plan/presentation/plan_cubit.dart';
import 'package:pantrypal/features/recipes/data/repositories/recipe_repository.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/subscription/bloc/subscription_cubit.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';
import 'package:pantrypal/injection_container.dart';

import '../support/di.dart';
import '../support/fixtures.dart';
import '../support/plugin_stubs.dart';
import '../support/test_db.dart';

Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
}

Widget app(Widget child) => MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PantryBloc(PantryRepository())..add(PantryLoad())),
        BlocProvider(create: (_) => RecipeBloc(RecipeRepository())..add(RecipeLoad())),
        BlocProvider(create: (_) => PlanCubit(PlanRepository(), PantryRepository())..load()),
        BlocProvider(create: (_) => ShoppingCubit(PantryRepository())),
        BlocProvider(create: (_) => SubscriptionCubit(SubscriptionService.instance)),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

/// A realistic small pantry the built-in recipes can cook from.
Future<void> stockPantry(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final i in [
      item(name: 'Eggs', category: FoodCategory.eggs, daysFromNow: 10, quantity: 6),
      item(name: 'Milk', daysFromNow: 2),
      item(name: 'Cheese', daysFromNow: 20),
      item(name: 'Butter', daysFromNow: 30),
      item(name: 'Chicken', category: FoodCategory.meat, daysFromNow: 1),
      item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 300),
      item(name: 'Onion', category: FoodCategory.vegetables, daysFromNow: 20),
      item(name: 'Tomatoes', category: FoodCategory.vegetables, daysFromNow: 3),
      item(name: 'Garlic', category: FoodCategory.vegetables, daysFromNow: 40),
      item(name: 'Bread', category: FoodCategory.grains, daysFromNow: 4),
      item(name: 'Pasta', category: FoodCategory.grains, daysFromNow: 300),
    ]) {
      await DatabaseHelper.instance.insertItem(i);
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestDatabase('plan_ui');
    stubNotificationPlugin();
    stubHomeWidgetPlugin();
  });

  setUp(() async {
    stubSharedPreferences();
    await registerTestDependencies();
    await sl<RecipeRepository>().seedIfEmpty();
    await DatabaseHelper.instance.clearAllData();
  });

  tearDown(resetTestDependencies);

  testWidgets('empty pantry asks for food instead of inventing a plan', (tester) async {
    await tester.pumpWidget(app(const PlanTab()));
    await settle(tester);
    expect(find.text('Add food to plan your meals'), findsOneWidget);
    expect(find.textContaining('Plan my next'), findsNothing);
  });

  testWidgets("headline speaks in terms of the user's own pantry", (tester) async {
    await stockPantry(tester);
    await tester.pumpWidget(app(const PlanTab()));
    await settle(tester);

    expect(find.textContaining('Your pantry can make'), findsOneWidget);
    expect(find.textContaining('using soon'), findsOneWidget);
    expect(find.textContaining('no shopping'), findsOneWidget);
    expect(find.textContaining('Plan my next'), findsOneWidget);
  });

  testWidgets('planning puts real meals on days, each with "Cooked it"', (tester) async {
    await stockPantry(tester);
    await tester.pumpWidget(app(const PlanTab()));
    await settle(tester);

    await tester.tap(find.textContaining('Plan my next'));
    await settle(tester);

    expect(find.textContaining('planned from your pantry'), findsOneWidget);
    expect(find.text('TONIGHT'), findsOneWidget);
    expect(find.text('Cooked it'), findsWidgets);
    expect(find.text('Swap'), findsWidgets);
  });

  testWidgets('"Cooked it" turns the meal into portions on the plan', (tester) async {
    await stockPantry(tester);
    await tester.pumpWidget(app(const PlanTab()));
    await settle(tester);
    await tester.tap(find.textContaining('Plan my next'));
    await settle(tester);

    await tester.tap(find.text('Cooked it').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Cooked '), findsWidgets);

    // Make 4, eat 2 → 2 leftovers.
    await tester.tap(find.byTooltip('More').first);
    await tester.tap(find.byTooltip('More').first);
    await tester.pump();
    await tester.tap(find.textContaining('Done'));
    await settle(tester);

    expect(find.textContaining('Ready to eat'), findsOneWidget);
    expect(find.text('Ate 1'), findsWidgets);
  });

  testWidgets('an everyday meal starts with 2 extra portions saved as leftovers', (tester) async {
    await stockPantry(tester);
    await tester.pumpWidget(app(const PlanTab()));
    await settle(tester);
    await tester.tap(find.textContaining('Plan my next'));
    await settle(tester);

    await tester.tap(find.text('Cooked it').first);
    await tester.pumpAndSettle();
    expect(find.text('Done · save 2 portions'), findsOneWidget, reason: 'made 4 for 2 people → 2 leftovers');

    await tester.tap(find.text('Done · save 2 portions'));
    await settle(tester);
    expect(find.text('Ready to eat · 2 portions'), findsOneWidget);
  });

  testWidgets('batch cook plan updates instantly as choices change', (tester) async {
    await stockPantry(tester);
    await tester.pumpWidget(app(const BatchCookPage()));
    await settle(tester);

    expect(find.textContaining('→ 8 portions'), findsOneWidget, reason: '2 people × 4 days × 1 meal');

    await tester.tap(find.text('6'));
    await tester.pump();
    expect(find.textContaining('→ 12 portions'), findsOneWidget);
    expect(find.textContaining('straight into the freezer'), findsOneWidget, reason: 'days 4–5 are frozen');

    await tester.tap(find.text('Lunch + dinner'));
    await tester.pump();
    expect(find.textContaining('→ 24 portions'), findsOneWidget);
    expect(find.text('Start batch cook'), findsOneWidget);
  });

  replanTests();
}

void replanTests() {
  testWidgets('re-planning with the same pantry says so instead of doing nothing visible', (tester) async {
    await stockPantry(tester);
    await tester.pumpWidget(app(const PlanTab()));
    await settle(tester);
    await tester.tap(find.textContaining('Plan my next'));
    await settle(tester);

    await tester.scrollUntilVisible(find.textContaining('Re-plan'), 200);
    await tester.tap(find.textContaining('Re-plan'));
    await settle(tester);

    expect(find.textContaining('Already the best plan'), findsOneWidget);
  });
}
