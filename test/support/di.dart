// Registers the GetIt graph the pages reach into directly.
//
// Some pages (ShoppingPage's restock suggestions, for example) resolve
// `sl<PantryRepository>()` rather than taking it from a bloc, so a widget test
// that pumps those pages needs a populated container.

import 'package:get_it/get_it.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/recipes/data/repositories/recipe_repository.dart';
import 'package:pantrypal/injection_container.dart';

Future<void> registerTestDependencies() async {
  await sl.reset();
  sl.registerLazySingleton<PantryRepository>(() => PantryRepository());
  sl.registerLazySingleton<RecipeRepository>(() => RecipeRepository());
}

Future<void> resetTestDependencies() => GetIt.instance.reset();
