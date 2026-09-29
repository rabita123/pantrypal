import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

class PantryRepository {
  final _db = DatabaseHelper.instance;

  Future<List<PantryItem>> getAllItems() => _db.getAllActiveItems();
  Future<List<PantryItem>> getItemsByLocation(StorageLocation loc) =>
      _db.getItemsByLocation(loc.name);
  Future<List<PantryItem>> getExpiringItems({int days = 7}) =>
      _db.getExpiringItems(withinDays: days);
  Future<List<PantryItem>> searchItems(String query) => _db.searchItems(query);
  Future<Map<String, dynamic>> getStats() => _db.getStats();

  Future<PantryItem> addItem(PantryItem item) async {
    await _db.insertItem(item);
    return item;
  }

  Future<PantryItem> updateItem(PantryItem item) async {
    await _db.updateItem(item);
    return item;
  }

  Future<void> markConsumed(String id) => _db.markConsumed(id);
  Future<void> markWasted(String id) => _db.markWasted(id);
  Future<void> deleteItem(String id) => _db.deleteItem(id);
  Future<List<PantryItem>> getRecentlyConsumed({int days = 30}) =>
      _db.getRecentlyConsumed(withinDays: days);

  // Shopping
  Future<List<ShoppingItem>> getShoppingItems() => _db.getAllShoppingItems();
  Future<void> addShoppingItem(ShoppingItem item) => _db.insertShoppingItem(item);
  Future<void> toggleShoppingItem(String id, bool checked) =>
      _db.toggleShoppingItem(id, checked);
  Future<void> deleteShoppingItem(String id) => _db.deleteShoppingItem(id);
  Future<void> clearChecked() => _db.clearCheckedShoppingItems();
}
