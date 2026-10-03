import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._();
  static DatabaseHelper get instance => _instance ??= DatabaseHelper._();

  Future<Database> get database async =>
      _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.itemsTable} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        location TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        expiry_date INTEGER NOT NULL,
        added_date INTEGER NOT NULL,
        price REAL,
        barcode TEXT,
        image_url TEXT,
        notes TEXT,
        is_consumed INTEGER NOT NULL DEFAULT 0,
        is_wasted INTEGER NOT NULL DEFAULT 0,
        resolved_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.shoppingTable} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        is_checked INTEGER NOT NULL DEFAULT 0,
        added_date INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_expiry ON ${AppConstants.itemsTable}(expiry_date)',
    );
    await db.execute(
      'CREATE INDEX idx_category ON ${AppConstants.itemsTable}(category)',
    );
    await db.execute(_mealsSql);
    await db.execute(_portionsSql);
  }


  static const _mealsSql = '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.mealsTable} (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        recipe_name TEXT NOT NULL,
        date INTEGER NOT NULL,
        servings INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'planned',
        batch_id TEXT,
        freeze_portions INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
  ''';

  static const _portionsSql = '''
      CREATE TABLE IF NOT EXISTS ${AppConstants.portionsTable} (
        id TEXT PRIMARY KEY,
        meal_id TEXT,
        recipe_name TEXT NOT NULL,
        total INTEGER NOT NULL,
        remaining INTEGER NOT NULL,
        location TEXT NOT NULL,
        cooked_at INTEGER NOT NULL,
        eat_by INTEGER NOT NULL,
        tossed INTEGER NOT NULL DEFAULT 0,
        finished_at INTEGER
      )
  ''';

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // When an item was used or binned — makes "this month" stats real.
      await db.execute(
        'ALTER TABLE ${AppConstants.itemsTable} ADD COLUMN resolved_at INTEGER',
      );
    }
    if (oldVersion < 3) {
      // Meal plans, batch cooks and the portions they leave.
      await db.execute(_mealsSql);
      await db.execute(_portionsSql);
    }
  }

  // ── PANTRY ITEMS ──────────────────────────────────────────────────────────

  Future<void> insertItem(PantryItem item) async {
    final db = await database;
    await db.insert(
      AppConstants.itemsTable,
      _itemToMap(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PantryItem>> getAllActiveItems() async {
    final db = await database;
    final maps = await db.query(
      AppConstants.itemsTable,
      where: 'is_consumed = 0 AND is_wasted = 0',
      orderBy: 'expiry_date ASC',
    );
    return maps.map(_mapToItem).toList();
  }

  Future<List<PantryItem>> getItemsByLocation(String location) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.itemsTable,
      where: 'location = ? AND is_consumed = 0 AND is_wasted = 0',
      whereArgs: [location],
      orderBy: 'expiry_date ASC',
    );
    return maps.map(_mapToItem).toList();
  }

  Future<List<PantryItem>> getExpiringItems({int withinDays = 7}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .add(Duration(days: withinDays))
        .millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query(
      AppConstants.itemsTable,
      where:
          'expiry_date <= ? AND expiry_date >= ? AND is_consumed = 0 AND is_wasted = 0',
      whereArgs: [cutoff, now],
      orderBy: 'expiry_date ASC',
    );
    return maps.map(_mapToItem).toList();
  }

  Future<List<PantryItem>> searchItems(String query) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.itemsTable,
      where: 'name LIKE ? AND is_consumed = 0 AND is_wasted = 0',
      whereArgs: ['%$query%'],
      orderBy: 'expiry_date ASC',
    );
    return maps.map(_mapToItem).toList();
  }

  Future<void> updateItem(PantryItem item) async {
    final db = await database;
    await db.update(
      AppConstants.itemsTable,
      _itemToMap(item),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> markConsumed(String id) async {
    final db = await database;
    await db.update(
      AppConstants.itemsTable,
      {'is_consumed': 1, 'resolved_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markWasted(String id) async {
    final db = await database;
    await db.update(
      AppConstants.itemsTable,
      {'is_wasted': 1, 'resolved_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.delete(AppConstants.itemsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final soonCutoff = DateTime.now()
        .add(const Duration(days: 7))
        .millisecondsSinceEpoch;

    final total = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.itemsTable} WHERE is_consumed=0 AND is_wasted=0',
          ),
        ) ??
        0;
    final expiringSoon = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.itemsTable} WHERE expiry_date <= ? AND expiry_date >= ? AND is_consumed=0 AND is_wasted=0',
            [soonCutoff, now],
          ),
        ) ??
        0;
    final expired = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.itemsTable} WHERE expiry_date < ? AND is_consumed=0 AND is_wasted=0',
            [now],
          ),
        ) ??
        0;
    final wasted = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.itemsTable} WHERE is_wasted=1',
          ),
        ) ??
        0;
    final consumed = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.itemsTable} WHERE is_consumed=1',
          ),
        ) ??
        0;
    final wastedValueRaw = (await db.rawQuery(
          'SELECT COALESCE(SUM(price), 0.0) FROM ${AppConstants.itemsTable} WHERE is_wasted=1',
        )).first.values.first;
    final wastedValue = ((wastedValueRaw as num?) ?? 0).toDouble();

    // This month's outcomes. Value uses the real price when there is one,
    // otherwise the category estimate, so every item counts.
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month)
        .millisecondsSinceEpoch;
    final resolved = await db.query(
      AppConstants.itemsTable,
      where: '(is_consumed = 1 OR is_wasted = 1) AND resolved_at >= ?',
      whereArgs: [monthStart],
    );
    var consumedMonth = 0, wastedMonth = 0;
    var savedValueMonth = 0.0, wastedValueMonth = 0.0;
    for (final row in resolved) {
      final item = _mapToItem(row);
      if (item.isConsumed) {
        consumedMonth++;
        savedValueMonth += item.estimatedValue;
      } else {
        wastedMonth++;
        wastedValueMonth += item.estimatedValue;
      }
    }

    return {
      'total': total,
      'expiringSoon': expiringSoon,
      'expired': expired,
      'wasted': wasted,
      'consumed': consumed,
      'wastedValue': wastedValue,
      'consumedMonth': consumedMonth,
      'wastedMonth': wastedMonth,
      'savedValueMonth': savedValueMonth,
      'wastedValueMonth': wastedValueMonth,
    };
  }

  /// Foods used up recently (newest first) — the honest source for "you might
  /// be out of…" suggestions.
  Future<List<PantryItem>> getRecentlyConsumed({int withinDays = 30}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: withinDays))
        .millisecondsSinceEpoch;
    final maps = await db.query(
      AppConstants.itemsTable,
      where: 'is_consumed = 1 AND resolved_at >= ?',
      whereArgs: [cutoff],
      orderBy: 'resolved_at DESC',
    );
    return maps.map(_mapToItem).toList();
  }

  // ── SHOPPING ITEMS ────────────────────────────────────────────────────────

  Future<void> insertShoppingItem(ShoppingItem item) async {
    final db = await database;
    await db.insert(
      AppConstants.shoppingTable,
      _shoppingToMap(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ShoppingItem>> getAllShoppingItems() async {
    final db = await database;
    final maps = await db.query(
      AppConstants.shoppingTable,
      orderBy: 'is_checked ASC, added_date DESC',
    );
    return maps.map(_mapToShoppingItem).toList();
  }

  Future<void> toggleShoppingItem(String id, bool isChecked) async {
    final db = await database;
    await db.update(
      AppConstants.shoppingTable,
      {'is_checked': isChecked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteShoppingItem(String id) async {
    final db = await database;
    await db.delete(
      AppConstants.shoppingTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearCheckedShoppingItems() async {
    final db = await database;
    await db.delete(
      AppConstants.shoppingTable,
      where: 'is_checked = 1',
    );
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(AppConstants.itemsTable);
    await db.delete(AppConstants.shoppingTable);
    await db.delete(AppConstants.mealsTable);
    await db.delete(AppConstants.portionsTable);
  }

  // ── MAPPERS ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _itemToMap(PantryItem item) => {
        'id': item.id,
        'name': item.name,
        'category': item.category.name,
        'location': item.location.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'expiry_date': item.expiryDate.millisecondsSinceEpoch,
        'added_date': item.addedDate.millisecondsSinceEpoch,
        'price': item.price,
        'barcode': item.barcode,
        'image_url': item.imageUrl,
        'notes': item.notes,
        'is_consumed': item.isConsumed ? 1 : 0,
        'is_wasted': item.isWasted ? 1 : 0,
      };

  PantryItem _mapToItem(Map<String, dynamic> m) => PantryItem(
        id: m['id'] as String,
        name: m['name'] as String,
        category: FoodCategory.fromString(m['category'] as String),
        location: StorageLocation.fromString(m['location'] as String),
        quantity: m['quantity'] as double,
        unit: m['unit'] as String,
        expiryDate: DateTime.fromMillisecondsSinceEpoch(m['expiry_date'] as int),
        addedDate: DateTime.fromMillisecondsSinceEpoch(m['added_date'] as int),
        price: (m['price'] as num?)?.toDouble(),
        barcode: m['barcode'] as String?,
        imageUrl: m['image_url'] as String?,
        notes: m['notes'] as String?,
        isConsumed: (m['is_consumed'] as int) == 1,
        isWasted: (m['is_wasted'] as int) == 1,
      );

  Map<String, dynamic> _shoppingToMap(ShoppingItem item) => {
        'id': item.id,
        'name': item.name,
        'category': item.category.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'is_checked': item.isChecked ? 1 : 0,
        'added_date': item.addedDate.millisecondsSinceEpoch,
        'notes': item.notes,
      };

  ShoppingItem _mapToShoppingItem(Map<String, dynamic> m) => ShoppingItem(
        id: m['id'] as String,
        name: m['name'] as String,
        category: FoodCategory.fromString(m['category'] as String),
        quantity: m['quantity'] as double,
        unit: m['unit'] as String,
        isChecked: (m['is_checked'] as int) == 1,
        addedDate: DateTime.fromMillisecondsSinceEpoch(m['added_date'] as int),
        notes: m['notes'] as String?,
      );
}
