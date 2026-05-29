class AppConstants {
  static const dbName = 'pantrypal.db';
  static const dbVersion = 1;
  static const itemsTable = 'pantry_items';
  static const shoppingTable = 'shopping_items';

  // Notification channels
  static const expiryChannelId = 'expiry_alerts';
  static const expiryChannelName = 'Expiry Alerts';

  // Expiry thresholds (days)
  static const expirySoonDays = 3;
  static const expiryWarnDays = 7;

  // Default shelf life by category (days)
  static const Map<String, int> defaultShelfLife = {
    'dairy': 7,
    'meat': 3,
    'vegetables': 5,
    'fruits': 7,
    'grains': 180,
    'frozen': 90,
    'beverages': 365,
    'snacks': 90,
    'condiments': 180,
    'other': 14,
  };

  // OCR parsing keywords
  static const List<String> skipKeywords = [
    'total', 'subtotal', 'tax', 'change', 'cash', 'card',
    'thank', 'visit', 'receipt', 'store', 'phone', 'www',
    'discount', 'savings', 'balance', 'tender', 'approve',
  ];

  // Common grocery items for fuzzy matching
  static const List<String> commonItems = [
    'milk', 'eggs', 'bread', 'butter', 'cheese', 'yogurt',
    'chicken', 'beef', 'pork', 'fish', 'salmon', 'tuna',
    'apple', 'banana', 'orange', 'tomato', 'potato', 'onion',
    'carrot', 'spinach', 'lettuce', 'broccoli', 'cucumber',
    'rice', 'pasta', 'flour', 'sugar', 'salt', 'oil',
    'coffee', 'tea', 'juice', 'water', 'soda',
    'cereal', 'oats', 'crackers', 'chips', 'cookies',
    'ketchup', 'mustard', 'mayo', 'sauce', 'vinegar',
  ];
}
