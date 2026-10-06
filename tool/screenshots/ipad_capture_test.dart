// Renders the real PantryPal screens at 12.9" iPad resolution (2048x2732)
// with sample food, for App Store iPad screenshots. Not part of the test
// suite — run on demand:
//
//   flutter test tool/screenshots/ipad_capture_test.dart --update-goldens
//
// Output: tool/screenshots/out/ipad_home.png, ipad_plan.png

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:pantrypal/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/shopping_cubit.dart';
import 'package:pantrypal/features/plan/data/plan_repository.dart';
import 'package:pantrypal/features/plan/domain/meal_planner.dart';
import 'package:pantrypal/features/plan/presentation/plan_cubit.dart';
import 'package:pantrypal/features/recipes/data/repositories/recipe_repository.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/subscription/bloc/subscription_cubit.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';
import 'package:pantrypal/injection_container.dart';

import '../../test/support/di.dart';
import '../../test/support/fixtures.dart';
import '../../test/support/plugin_stubs.dart';
import '../../test/support/test_db.dart';

const _fontDir = String.fromEnvironment('FONT_DIR');

Future<void> _loadFonts() async {
  final nunito = FontLoader('Nunito');
  for (final f in Directory(_fontDir).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
    nunito.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  }
  await nunito.load();
  final emoji = FontLoader('Apple Color Emoji');
  emoji.addFont(Future.value(
      ByteData.view(File('/System/Library/Fonts/Apple Color Emoji.ttc').readAsBytesSync().buffer)));
  await emoji.load();
  // Material icons and symbols (→ etc.) — present on a device, not in tests.
  final icons = FontLoader('MaterialIcons');
  icons.addFont(Future.value(ByteData.view(
      File('/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync().buffer)));
  await icons.load();
  final symbols = FontLoader('Arial Unicode');
  symbols.addFont(Future.value(
      ByteData.view(File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf').readAsBytesSync().buffer)));
  await symbols.load();
}

Future<void> settle(WidgetTester tester, [int rounds = 14]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _seed() async {
  final db = DatabaseHelper.instance;
  final pantry = [
    item(name: 'Spinach', category: FoodCategory.vegetables, daysFromNow: 1, price: 2.99),
    item(name: 'Chicken Breast', category: FoodCategory.meat, daysFromNow: 2, price: 8.49),
    item(name: 'Tomatoes', category: FoodCategory.vegetables, daysFromNow: 2, price: 3.29),
    item(name: 'Milk', daysFromNow: 3, price: 3.49),
    item(name: 'Greek Yogurt', daysFromNow: 5, price: 4.29),
    item(name: 'Eggs', category: FoodCategory.eggs, daysFromNow: 12, quantity: 12),
    item(name: 'Bread', category: FoodCategory.grains, daysFromNow: 4),
    item(name: 'Bananas', category: FoodCategory.fruits, daysFromNow: 5),
    item(name: 'Cheese', daysFromNow: 18),
    item(name: 'Butter', daysFromNow: 30),
    item(name: 'Onions', category: FoodCategory.vegetables, daysFromNow: 25, location: StorageLocation.pantry),
    item(name: 'Garlic', category: FoodCategory.vegetables, daysFromNow: 45, location: StorageLocation.pantry),
    item(name: 'Rice', category: FoodCategory.grains, daysFromNow: 300, location: StorageLocation.pantry),
    item(name: 'Pasta', category: FoodCategory.grains, daysFromNow: 300, location: StorageLocation.pantry),
    item(name: 'Carrots', category: FoodCategory.vegetables, daysFromNow: 14),
  ];
  for (final p in pantry) {
    await db.insertItem(p);
  }
  // Some history so "This month" shows real numbers.
  for (final (n, price) in [('Lettuce', 2.49), ('Salmon', 9.99), ('Apples', 3.99), ('Yogurt', 3.29), ('Peppers', 2.99)]) {
    final i = item(name: n, price: price);
    await db.insertItem(i);
    await db.markConsumed(i.id);
  }
  final binned = item(name: 'Cream', price: 2.79);
  await db.insertItem(binned);
  await db.markWasted(binned.id);

  // A 3-day plan from the pantry, and leftovers from last night.
  final recipes = await sl<RecipeRepository>().getAll();
  final draft = MealPlanner.plan(recipes: recipes, pantry: pantry, days: 3);
  final plans = PlanRepository();
  await plans.insertMeals([
    for (final d in draft)
      PlannedMeal(id: nextId('m'), recipeId: d.option.recipe.id, recipeName: d.option.recipe.name, date: d.date, servings: 2),
  ]);
  final now = DateTime.now();
  await plans.insertPortion(PortionBatch(
    id: nextId('p'),
    recipeName: 'Vegetable Soup',
    total: 3,
    remaining: 2,
    location: PortionLocation.fridge,
    cookedAt: now.subtract(const Duration(days: 1)),
    eatBy: DateTime(now.year, now.month, now.day + 2, 12),
  ));
}

final _shotKey = GlobalKey();

/// Full-resolution capture (devicePixelRatio 2 → 2048x2732).
Future<void> capture(WidgetTester tester, String path) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestDatabase('ipad_shots');
    stubNotificationPlugin();
    stubHomeWidgetPlugin();
    await _loadFonts();
  });

  testWidgets('render iPad screens', (tester) async {
    debugDisableShadows = false; // real shadows, not test outlines
    stubSharedPreferences({'onboarding_done': true, 'ai_consent': true, 'analytics_enabled': false});
    await registerTestDependencies();
    await tester.runAsync(() async {
      await sl<RecipeRepository>().seedIfEmpty();
      await DatabaseHelper.instance.clearAllData();
      await _seed();
    });

    tester.view.physicalSize = const Size(2048, 2732);
    tester.view.devicePixelRatio = 2.0;
    tester.view.padding = const FakeViewPadding(top: 64, bottom: 40);
    tester.view.viewPadding = const FakeViewPadding(top: 64, bottom: 40);
    addTearDown(tester.view.reset);

    final base = AppTheme.light(fontFamily: 'Nunito');
    final theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Nunito', fontFamilyFallback: const ['Apple Color Emoji', 'Arial Unicode']),
    );

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PantryBloc(PantryRepository())),
        BlocProvider(create: (_) => RecipeBloc(RecipeRepository())..add(RecipeLoad())),
        BlocProvider(create: (_) => ShoppingCubit(PantryRepository())),
        BlocProvider(create: (_) => PlanCubit(PlanRepository(), PantryRepository())..load()),
        BlocProvider(create: (_) => SubscriptionCubit(SubscriptionService.instance)),
      ],
      child: RepaintBoundary(
        key: _shotKey,
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: theme, home: const DashboardPage()),
      ),
    ));
    await settle(tester);
    await capture(tester, 'tool/screenshots/out/ipad_home.png');

    await tester.tap(find.text('Plan').last);
    await settle(tester);
    await capture(tester, 'tool/screenshots/out/ipad_plan.png');
    debugDisableShadows = true; // restore before the test framework checks
  });
}
