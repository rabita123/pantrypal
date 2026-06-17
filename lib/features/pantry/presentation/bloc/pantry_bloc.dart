import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/shared/services/widget_service.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class PantryEvent extends Equatable {
  @override List<Object?> get props => [];
}

class PantryLoad extends PantryEvent {}
class PantrySearch extends PantryEvent {
  final String query;
  PantrySearch(this.query);
  @override List<Object?> get props => [query];
}
class PantryClearSearch extends PantryEvent {}
class PantryFilterByLocation extends PantryEvent {
  final StorageLocation? location;
  PantryFilterByLocation(this.location);
  @override List<Object?> get props => [location];
}
class PantryAddItem extends PantryEvent {
  final PantryItem item;
  PantryAddItem(this.item);
  @override List<Object?> get props => [item];
}
class PantryUpdateItem extends PantryEvent {
  final PantryItem item;
  PantryUpdateItem(this.item);
  @override List<Object?> get props => [item];
}
class PantryMarkConsumed extends PantryEvent {
  final String id;
  PantryMarkConsumed(this.id);
  @override List<Object?> get props => [id];
}
class PantryMarkWasted extends PantryEvent {
  final String id;
  PantryMarkWasted(this.id);
  @override List<Object?> get props => [id];
}
class PantryDeleteItem extends PantryEvent {
  final String id;
  PantryDeleteItem(this.id);
  @override List<Object?> get props => [id];
}
class PantryAddItems extends PantryEvent {
  final List<PantryItem> items;
  PantryAddItems(this.items);
}

// Shopping events
class ShoppingLoad extends PantryEvent {}
class ShoppingAddItem extends PantryEvent {
  final ShoppingItem item;
  ShoppingAddItem(this.item);
  @override List<Object?> get props => [item];
}
class ShoppingToggleItem extends PantryEvent {
  final String id;
  final bool checked;
  ShoppingToggleItem(this.id, this.checked);
  @override List<Object?> get props => [id, checked];
}
class ShoppingDeleteItem extends PantryEvent {
  final String id;
  ShoppingDeleteItem(this.id);
  @override List<Object?> get props => [id];
}
class ShoppingClearDone extends PantryEvent {}

// ── States ────────────────────────────────────────────────────────────────────

abstract class PantryState extends Equatable {
  @override List<Object?> get props => [];
}

class PantryInitial extends PantryState {}
class PantryLoading extends PantryState {}

class PantryLoaded extends PantryState {
  final List<PantryItem> items;
  final List<PantryItem> allItems;
  final List<PantryItem> expiringItems;
  final Map<String, dynamic> stats;
  final String searchQuery;
  final StorageLocation? activeLocation;

  PantryLoaded({
    required this.items,
    required this.allItems,
    required this.expiringItems,
    required this.stats,
    this.searchQuery = '',
    this.activeLocation,
  });

  @override
  List<Object?> get props => [items, searchQuery, activeLocation, stats];
}

class PantryError extends PantryState {
  final String message;
  PantryError(this.message);
  @override List<Object?> get props => [message];
}

class ShoppingLoaded extends PantryState {
  final List<ShoppingItem> items;
  ShoppingLoaded(this.items);
  @override List<Object?> get props => [items];
}

// ── BLoC ──────────────────────────────────────────────────────────────────────

class PantryBloc extends Bloc<PantryEvent, PantryState> {
  final PantryRepository _repository;

  PantryBloc(this._repository) : super(PantryInitial()) {
    on<PantryLoad>(_onLoad);
    on<PantrySearch>(_onSearch);
    on<PantryClearSearch>(_onClearSearch);
    on<PantryFilterByLocation>(_onFilterLocation);
    on<PantryAddItem>(_onAddItem);
    on<PantryAddItems>(_onAddItems);
    on<PantryUpdateItem>(_onUpdateItem);
    on<PantryMarkConsumed>(_onMarkConsumed);
    on<PantryMarkWasted>(_onMarkWasted);
    on<PantryDeleteItem>(_onDelete);
    on<ShoppingLoad>(_onShoppingLoad);
    on<ShoppingAddItem>(_onShoppingAdd);
    on<ShoppingToggleItem>(_onShoppingToggle);
    on<ShoppingDeleteItem>(_onShoppingDelete);
    on<ShoppingClearDone>(_onShoppingClearDone);
  }

  Future<void> _onLoad(PantryLoad event, Emitter<PantryState> emit) async {
    emit(PantryLoading());
    try {
      final items = await _repository.getAllItems();
      final expiring = await _repository.getExpiringItems(days: 7);
      final stats = await _repository.getStats();
      emit(PantryLoaded(
        items: items,
        allItems: items,
        expiringItems: expiring,
        stats: stats,
      ));
      WidgetService.updateWidget(
        expiringItems: expiring,
        totalItems: items.length,
      ).ignore();
    } catch (e) {
      emit(PantryError(e.toString()));
    }
  }

  Future<void> _onSearch(PantrySearch event, Emitter<PantryState> emit) async {
    final current = state;
    if (current is PantryLoaded) {
      if (event.query.isEmpty) {
        emit(PantryLoaded(
          items: current.allItems,
          allItems: current.allItems,
          expiringItems: current.expiringItems,
          stats: current.stats,
        ));
        return;
      }
      final results = await _repository.searchItems(event.query);
      emit(PantryLoaded(
        items: results,
        allItems: current.allItems,
        expiringItems: current.expiringItems,
        stats: current.stats,
        searchQuery: event.query,
      ));
    }
  }

  Future<void> _onClearSearch(PantryClearSearch event, Emitter<PantryState> emit) async {
    final current = state;
    if (current is PantryLoaded) {
      emit(PantryLoaded(
        items: current.allItems,
        allItems: current.allItems,
        expiringItems: current.expiringItems,
        stats: current.stats,
      ));
    }
  }

  Future<void> _onFilterLocation(PantryFilterByLocation event, Emitter<PantryState> emit) async {
    final current = state;
    if (current is PantryLoaded) {
      List<PantryItem> filtered;
      if (event.location == null) {
        filtered = current.allItems;
      } else {
        filtered = await _repository.getItemsByLocation(event.location!);
      }
      emit(PantryLoaded(
        items: filtered,
        allItems: current.allItems,
        expiringItems: current.expiringItems,
        stats: current.stats,
        activeLocation: event.location,
      ));
    }
  }

  Future<void> _onAddItem(PantryAddItem event, Emitter<PantryState> emit) async {
    try {
      await _repository.addItem(event.item);
      add(PantryLoad());
    } catch (e) {
      emit(PantryError(e.toString()));
    }
  }

  Future<void> _onAddItems(PantryAddItems event, Emitter<PantryState> emit) async {
    try {
      for (final item in event.items) {
        await _repository.addItem(item);
      }
      add(PantryLoad());
    } catch (e) {
      emit(PantryError(e.toString()));
    }
  }

  Future<void> _onUpdateItem(PantryUpdateItem event, Emitter<PantryState> emit) async {
    try {
      await _repository.updateItem(event.item);
      add(PantryLoad());
    } catch (e) {
      emit(PantryError(e.toString()));
    }
  }

  Future<void> _onMarkConsumed(PantryMarkConsumed event, Emitter<PantryState> emit) async {
    await _repository.markConsumed(event.id);
    add(PantryLoad());
  }

  Future<void> _onMarkWasted(PantryMarkWasted event, Emitter<PantryState> emit) async {
    await _repository.markWasted(event.id);
    add(PantryLoad());
  }

  Future<void> _onDelete(PantryDeleteItem event, Emitter<PantryState> emit) async {
    await _repository.deleteItem(event.id);
    add(PantryLoad());
  }

  Future<void> _onShoppingLoad(ShoppingLoad event, Emitter<PantryState> emit) async {
    final items = await _repository.getShoppingItems();
    emit(ShoppingLoaded(items));
  }

  Future<void> _onShoppingAdd(ShoppingAddItem event, Emitter<PantryState> emit) async {
    await _repository.addShoppingItem(event.item);
    add(ShoppingLoad());
  }

  Future<void> _onShoppingToggle(ShoppingToggleItem event, Emitter<PantryState> emit) async {
    await _repository.toggleShoppingItem(event.id, event.checked);
    add(ShoppingLoad());
  }

  Future<void> _onShoppingDelete(ShoppingDeleteItem event, Emitter<PantryState> emit) async {
    await _repository.deleteShoppingItem(event.id);
    add(ShoppingLoad());
  }

  Future<void> _onShoppingClearDone(ShoppingClearDone event, Emitter<PantryState> emit) async {
    await _repository.clearChecked();
    add(ShoppingLoad());
  }
}
