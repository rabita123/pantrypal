import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/shared/services/notification_service.dart';

class PantryRepository {
  final _db = DatabaseHelper.instance;
  final _notifications = NotificationService.instance;

  Future<List<PantryItem>> getAllItems() => _db.getAllActiveItems();
  Future<List<PantryItem>> getItemsByLocation(StorageLocation loc) =>
      _db.getItemsByLocation(loc.name);
  Future<List<PantryItem>> getExpiringItems({int days = 7}) =>
      _db.getExpiringItems(withinDays: days);
  Future<List<PantryItem>> searchItems(String query) => _db.searchItems(query);
  Future<Map<String, dynamic>> getStats() => _db.getStats();

  Future<PantryItem> addItem(PantryItem item) async {
    await _db.insertItem(item);
    await _notifications.scheduleExpiryReminder(item);
    return item;
  }

  Future<PantryItem> updateItem(PantryItem item) async {
    await _db.updateItem(item);
    await _notifications.cancelReminder(item.id);
    await _notifications.scheduleExpiryReminder(item);
    return item;
  }

  Future<void> markConsumed(String id) async {
    await _db.markConsumed(id);
    await _notifications.cancelReminder(id);
  }

  Future<void> markWasted(String id) async {
    await _db.markWasted(id);
    await _notifications.cancelReminder(id);
  }

  Future<void> deleteItem(String id) async {
    await _db.deleteItem(id);
    await _notifications.cancelReminder(id);
  }

  // Shopping
  Future<List<ShoppingItem>> getShoppingItems() => _db.getAllShoppingItems();
  Future<void> addShoppingItem(ShoppingItem item) => _db.insertShoppingItem(item);
  Future<void> toggleShoppingItem(String id, bool checked) =>
      _db.toggleShoppingItem(id, checked);
  Future<void> deleteShoppingItem(String id) => _db.deleteShoppingItem(id);
  Future<void> clearChecked() => _db.clearCheckedShoppingItems();
}
