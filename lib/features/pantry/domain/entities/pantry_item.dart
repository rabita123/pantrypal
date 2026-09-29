import 'package:equatable/equatable.dart';

enum FoodCategory {
  dairy('Dairy', '🥛', 0xFF1976D2),
  eggs('Eggs', '🥚', 0xFFFFA000),
  meat('Meat & Fish', '🥩', 0xFFC62828),
  vegetables('Vegetables', '🥦', 0xFF388E3C),
  fruits('Fruits', '🍎', 0xFFE65100),
  grains('Grains & Bread', '🍞', 0xFF795548),
  frozen('Frozen', '🧊', 0xFF0288D1),
  beverages('Beverages', '🧃', 0xFF7B1FA2),
  snacks('Snacks', '🍿', 0xFFF9A825),
  condiments('Condiments', '🧂', 0xFF00695C),
  other('Other', '📦', 0xFF546E7A);

  final String label;
  final String emoji;
  final int colorValue;
  const FoodCategory(this.label, this.emoji, this.colorValue);

  static FoodCategory fromString(String s) {
    return FoodCategory.values.firstWhere(
      (e) => e.name == s,
      orElse: () => FoodCategory.other,
    );
  }

  /// Where this kind of food normally lives — used so a scan never asks the
  /// user to sort rice into the fridge.
  StorageLocation get defaultLocation => switch (this) {
        FoodCategory.dairy ||
        FoodCategory.eggs ||
        FoodCategory.meat ||
        FoodCategory.vegetables ||
        FoodCategory.fruits =>
          StorageLocation.fridge,
        FoodCategory.frozen => StorageLocation.freezer,
        _ => StorageLocation.pantry,
      };

  /// Rough shelf price in dollars, used only to estimate how much money an
  /// item without a price represents. Always shown as an estimate ("~").
  double get averagePrice => switch (this) {
        FoodCategory.dairy => 3.5,
        FoodCategory.eggs => 3.5,
        FoodCategory.meat => 8.0,
        FoodCategory.vegetables => 2.5,
        FoodCategory.fruits => 3.0,
        FoodCategory.grains => 3.0,
        FoodCategory.frozen => 5.0,
        FoodCategory.beverages => 3.0,
        FoodCategory.snacks => 3.5,
        FoodCategory.condiments => 3.5,
        FoodCategory.other => 3.0,
      };
}

enum ExpiryStatus { fresh, expiringSoon, expired }

enum StorageLocation {
  fridge('Fridge', '❄️'),
  freezer('Freezer', '🧊'),
  pantry('Pantry', '🏠'),
  counter('Counter', '🍽️');

  final String label;
  final String emoji;
  const StorageLocation(this.label, this.emoji);

  static StorageLocation fromString(String s) {
    return StorageLocation.values.firstWhere(
      (e) => e.name == s,
      orElse: () => StorageLocation.pantry,
    );
  }
}

class PantryItem extends Equatable {
  final String id;
  final String name;
  final FoodCategory category;
  final StorageLocation location;
  final double quantity;
  final String unit;
  final DateTime expiryDate;
  final DateTime addedDate;
  final double? price;
  final String? barcode;
  final String? imageUrl;
  final String? notes;
  final bool isConsumed;
  final bool isWasted;

  const PantryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
    required this.addedDate,
    this.price,
    this.barcode,
    this.imageUrl,
    this.notes,
    required this.isConsumed,
    required this.isWasted,
  });

  /// An expiry date [days] from today, pinned to midday so the calendar day
  /// is unambiguous whatever the time of adding.
  static DateTime expiryInDays(int days, {DateTime? from}) {
    final now = from ?? DateTime.now();
    return DateTime(now.year, now.month, now.day + days, 12);
  }

  /// Calendar days until expiry (0 = today, negative = already expired).
  ///
  /// Counted in calendar days, not 24-hour blocks: an item added this
  /// afternoon with 3 days of life reads "3 days", not "2".
  int get daysUntilExpiry {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final expiry = DateTime.utc(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  ExpiryStatus get expiryStatus {
    final daysLeft = daysUntilExpiry;
    if (daysLeft < 0) return ExpiryStatus.expired;
    if (daysLeft <= 3) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.fresh;
  }

  /// What this item is worth: its real price when known, otherwise an
  /// estimate from its category.
  double get estimatedValue => price ?? category.averagePrice;

  /// Whether [estimatedValue] is a guess rather than a scanned/typed price.
  bool get isValueEstimated => price == null;

  bool get isActive => !isConsumed && !isWasted;

  String get expiryLabel {
    final days = daysUntilExpiry;
    if (days < 0) return 'Expired ${(-days)} day${(-days) == 1 ? '' : 's'} ago';
    if (days == 0) return 'Expires today!';
    if (days == 1) return 'Expires tomorrow';
    return 'Expires in $days days';
  }

  PantryItem copyWith({
    String? name,
    FoodCategory? category,
    StorageLocation? location,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    double? price,
    String? barcode,
    String? imageUrl,
    String? notes,
    bool? isConsumed,
    bool? isWasted,
  }) {
    return PantryItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      location: location ?? this.location,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      addedDate: addedDate,
      price: price ?? this.price,
      barcode: barcode ?? this.barcode,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      isConsumed: isConsumed ?? this.isConsumed,
      isWasted: isWasted ?? this.isWasted,
    );
  }

  @override
  List<Object?> get props => [id, name, expiryDate, category];
}

class ShoppingItem extends Equatable {
  final String id;
  final String name;
  final FoodCategory category;
  final double quantity;
  final String unit;
  final bool isChecked;
  final DateTime addedDate;
  final String? notes;

  const ShoppingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.isChecked,
    required this.addedDate,
    this.notes,
  });

  ShoppingItem copyWith({bool? isChecked, double? quantity}) {
    return ShoppingItem(
      id: id,
      name: name,
      category: category,
      quantity: quantity ?? this.quantity,
      unit: unit,
      isChecked: isChecked ?? this.isChecked,
      addedDate: addedDate,
      notes: notes,
    );
  }

  @override
  List<Object?> get props => [id, name, isChecked];
}
