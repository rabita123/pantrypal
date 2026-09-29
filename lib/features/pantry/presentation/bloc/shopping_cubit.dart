import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/utils/grocery_ocr_parser.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:uuid/uuid.dart';

class ShoppingState extends Equatable {
  final List<ShoppingItem> items;
  final bool loaded;
  const ShoppingState({this.items = const [], this.loaded = false});

  @override
  List<Object?> get props => [items, loaded];
}

/// The shopping list. Kept apart from [PantryBloc] so that touching the list
/// can never blank the pantry or Home screen.
class ShoppingCubit extends Cubit<ShoppingState> {
  final PantryRepository _repository;
  static const _uuid = Uuid();

  ShoppingCubit(this._repository) : super(const ShoppingState());

  Future<void> load() async {
    final items = await _repository.getShoppingItems();
    emit(ShoppingState(items: items, loaded: true));
  }

  Future<void> add(ShoppingItem item) async {
    await _repository.addShoppingItem(item);
    await load();
  }

  /// Adds names that are not already on the (unchecked) list. Returns how many
  /// were actually added.
  Future<int> addNames(Iterable<String> names) async {
    final existing = state.items
        .where((i) => !i.isChecked)
        .map((i) => i.name.toLowerCase().trim())
        .toSet();
    var added = 0;
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty || !existing.add(name.toLowerCase())) continue;
      await _repository.addShoppingItem(ShoppingItem(
        id: _uuid.v4(),
        name: name,
        category: GroceryOcrParser.guessCategory(name),
        quantity: 1,
        unit: 'pcs',
        isChecked: false,
        addedDate: DateTime.now(),
      ));
      added++;
    }
    await load();
    return added;
  }

  Future<void> toggle(String id, bool checked) async {
    await _repository.toggleShoppingItem(id, checked);
    await load();
  }

  Future<void> delete(String id) async {
    await _repository.deleteShoppingItem(id);
    await load();
  }

  Future<void> clearDone() async {
    await _repository.clearChecked();
    await load();
  }
}
