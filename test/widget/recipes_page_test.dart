// The recipes empty state is a fixed-height Column inside a Center. When the
// search field is focused the keyboard takes roughly a third of the screen,
// and the column has no room to shrink or scroll — it overflows.
//
// Found by the on-device E2E run ("A RenderFlex overflowed by 24 pixels on the
// bottom") and pinned here so it reproduces without a phone.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/recipes/data/repositories/recipe_repository.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/recipes/presentation/pages/recipes_page.dart';

import '../support/plugin_stubs.dart';

/// Pumps the page at a real handset size, optionally with a keyboard showing.
Future<void> pumpRecipes(
  WidgetTester tester, {
  double keyboardHeight = 0,
}) async {
  tester.view.physicalSize = const Size(1170, 2532); // iPhone 13/14 class
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          viewInsets: EdgeInsets.only(bottom: keyboardHeight),
        ),
        child: BlocProvider(
          create: (_) => RecipeBloc(RecipeRepository())..add(RecipeLoad()),
          child: const RecipesPage(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => stubSharedPreferences());

  testWidgets('empty state renders with no keyboard', (tester) async {
    await pumpRecipes(tester);
    expect(find.text('No recipes yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state does not overflow when the keyboard is open',
      (tester) async {
    // 336pt is a typical iPhone keyboard with the accessory bar.
    await pumpRecipes(tester, keyboardHeight: 336);

    expect(tester.takeException(), isNull,
        reason: 'the empty state must fit or scroll when the search field '
            'is focused and the keyboard covers the lower third');
  });

  testWidgets('empty state survives a very short viewport', (tester) async {
    await pumpRecipes(tester, keyboardHeight: 500);
    expect(tester.takeException(), isNull);
  });
}
