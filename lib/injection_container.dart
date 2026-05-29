import 'package:get_it/get_it.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/recipes/data/repositories/recipe_repository.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/subscription/bloc/subscription_cubit.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';
import 'package:pantrypal/shared/services/notification_service.dart';

final sl = GetIt.instance;

Future<void> setupDependencies() async {
  sl.registerLazySingleton<NotificationService>(() => NotificationService.instance);
  sl.registerLazySingleton<SubscriptionService>(() => SubscriptionService.instance);
  sl.registerFactory<SubscriptionCubit>(() => SubscriptionCubit(sl<SubscriptionService>()));
  sl.registerLazySingleton<PantryRepository>(() => PantryRepository());
  sl.registerLazySingleton<RecipeRepository>(() => RecipeRepository());
  sl.registerFactory<PantryBloc>(() => PantryBloc(sl<PantryRepository>()));
  sl.registerFactory<RecipeBloc>(() => RecipeBloc(sl<RecipeRepository>()));
}
