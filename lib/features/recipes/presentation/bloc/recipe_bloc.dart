import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/features/recipes/data/repositories/recipe_repository.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';

// ── Events ─────────────────────────────────────────────────────────────────

abstract class RecipeEvent extends Equatable {
  @override List<Object?> get props => [];
}

class RecipeLoad extends RecipeEvent {}

class RecipeSave extends RecipeEvent {
  final Recipe recipe;
  RecipeSave(this.recipe);
  @override List<Object?> get props => [recipe];
}

class RecipeDelete extends RecipeEvent {
  final String id;
  RecipeDelete(this.id);
  @override List<Object?> get props => [id];
}

class RecipeToggleFavorite extends RecipeEvent {
  final String id;
  RecipeToggleFavorite(this.id);
  @override List<Object?> get props => [id];
}

class RecipeSetFilter extends RecipeEvent {
  final DietaryTag? dietary;
  final Cuisine? cuisine;
  final bool? favoritesOnly;
  RecipeSetFilter({this.dietary, this.cuisine, this.favoritesOnly});
  @override List<Object?> get props => [dietary, cuisine, favoritesOnly];
}

class RecipeSearch extends RecipeEvent {
  final String query;
  RecipeSearch(this.query);
  @override List<Object?> get props => [query];
}

// ── States ──────────────────────────────────────────────────────────────────

abstract class RecipeState extends Equatable {
  @override List<Object?> get props => [];
}

class RecipeInitial extends RecipeState {}
class RecipeLoading extends RecipeState {}

class RecipeLoaded extends RecipeState {
  final List<Recipe> all;
  final List<Recipe> filtered;
  final DietaryTag? activeDietary;
  final Cuisine? activeCuisine;
  final bool favoritesOnly;
  final String searchQuery;

  RecipeLoaded({
    required this.all,
    required this.filtered,
    this.activeDietary,
    this.activeCuisine,
    this.favoritesOnly = false,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [all, filtered, activeDietary, activeCuisine, favoritesOnly, searchQuery];
}

class RecipeError extends RecipeState {
  final String message;
  RecipeError(this.message);
  @override List<Object?> get props => [message];
}

// ── BLoC ────────────────────────────────────────────────────────────────────

class RecipeBloc extends Bloc<RecipeEvent, RecipeState> {
  final RecipeRepository _repo;

  RecipeBloc(this._repo) : super(RecipeInitial()) {
    on<RecipeLoad>(_onLoad);
    on<RecipeSave>(_onSave);
    on<RecipeDelete>(_onDelete);
    on<RecipeToggleFavorite>(_onToggleFavorite);
    on<RecipeSetFilter>(_onSetFilter);
    on<RecipeSearch>(_onSearch);
  }

  Future<void> _onLoad(RecipeLoad event, Emitter<RecipeState> emit) async {
    emit(RecipeLoading());
    try {
      final all = await _repo.getAll();
      emit(RecipeLoaded(all: all, filtered: all));
    } catch (e) {
      emit(RecipeError(e.toString()));
    }
  }

  Future<void> _onSave(RecipeSave event, Emitter<RecipeState> emit) async {
    await _repo.save(event.recipe);
    add(RecipeLoad());
  }

  Future<void> _onDelete(RecipeDelete event, Emitter<RecipeState> emit) async {
    await _repo.delete(event.id);
    add(RecipeLoad());
  }

  Future<void> _onToggleFavorite(RecipeToggleFavorite event, Emitter<RecipeState> emit) async {
    await _repo.toggleFavorite(event.id);
    final current = state;
    if (current is RecipeLoaded) {
      final all = await _repo.getAll();
      emit(RecipeLoaded(
        all: all,
        filtered: _applyFilters(all, current.activeDietary, current.activeCuisine, current.favoritesOnly, current.searchQuery),
        activeDietary: current.activeDietary,
        activeCuisine: current.activeCuisine,
        favoritesOnly: current.favoritesOnly,
        searchQuery: current.searchQuery,
      ));
    }
  }

  Future<void> _onSetFilter(RecipeSetFilter event, Emitter<RecipeState> emit) async {
    final current = state;
    if (current is RecipeLoaded) {
      final dietary = event.dietary;
      final cuisine = event.cuisine;
      final favOnly = event.favoritesOnly ?? current.favoritesOnly;
      emit(RecipeLoaded(
        all: current.all,
        filtered: _applyFilters(current.all, dietary, cuisine, favOnly, current.searchQuery),
        activeDietary: dietary,
        activeCuisine: cuisine,
        favoritesOnly: favOnly,
        searchQuery: current.searchQuery,
      ));
    }
  }

  Future<void> _onSearch(RecipeSearch event, Emitter<RecipeState> emit) async {
    final current = state;
    if (current is RecipeLoaded) {
      emit(RecipeLoaded(
        all: current.all,
        filtered: _applyFilters(current.all, current.activeDietary, current.activeCuisine, current.favoritesOnly, event.query),
        activeDietary: current.activeDietary,
        activeCuisine: current.activeCuisine,
        favoritesOnly: current.favoritesOnly,
        searchQuery: event.query,
      ));
    }
  }

  List<Recipe> _applyFilters(
    List<Recipe> all,
    DietaryTag? dietary,
    Cuisine? cuisine,
    bool favOnly,
    String query,
  ) {
    return all.where((r) {
      if (favOnly && !r.isFavorite) return false;
      if (dietary != null && !r.dietaryTags.contains(dietary)) return false;
      if (cuisine != null && cuisine != Cuisine.any && r.cuisine != cuisine) return false;
      if (query.isNotEmpty && !r.name.toLowerCase().contains(query.toLowerCase())) return false;
      return true;
    }).toList();
  }
}
