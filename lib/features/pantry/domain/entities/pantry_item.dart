import 'package:equatable/equatable.dart';

enum FoodCategory {
  dairy('Dairy', '🥛', 0xFF1976D2),
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

  ExpiryStatus get expiryStatus {
    final now = DateTime.now();
    final daysLeft = expiryDate.difference(now).inDays;
    if (now.isAfter(expiryDate)) return ExpiryStatus.expired;
    if (daysLeft <= 3) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.fresh;
  }

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;

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
