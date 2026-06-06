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
    'eggs': 21,
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

  // OCR skip keywords — matched as substrings against lowercased lines.
  // Safe to use bare words that NEVER appear in food product names.
  // Use specific phrases for words that could appear in product names.
  static const List<String> skipKeywords = [
    // Summary / totals (never in food names)
    'total', 'subtotal',
    // Tax lines
    'tax', 'vat', 'hst', 'gst',
    // Payment / transaction
    'change due', 'amount due', 'amount paid',
    'cash tendered', 'cash back',
    'card payment', 'card tender',
    'visa', 'mastercard', 'amex', 'discover',
    'debit', 'credit card',
    // Loyalty / rewards
    'loyalty card', 'reward point', 'fuel point',
    'member saving', 'member discount',
    'gift card',
    // Receipt metadata (never in food names)
    'thank you',
    'receipt no', 'receipt #',
    'transaction', 'operator',
    'store #', 'store no.', 'register #', 'register no',
    'approved', 'authorization',
    // Coupons / discounts
    'coupon', 'instant save',
    // Address / contact
    '.com', 'tel:', 'fax:',
    'customer service',
    // Invoice / store metadata (South Asian receipts)
    'bin no', 'bin:', 'invoice no', 'invoice date', 'print date',
    'pos user', 'pos terminal', 'business hour',
    'helpline', 'helpline:',
    'customer name', 'customer mobile', 'customer address',
    'net payable', 'bank paid', 'cash paid', 'paid amount', 'change amount',
    'redeem point', 'inword', 'in word',
    'payment information', 'payment info',
  ];

  // Common grocery items for fuzzy matching (freetext fallback)
  static const List<String> commonItems = [
    'milk', 'egg', 'eggs', 'bread', 'butter', 'cheese', 'yogurt', 'yoghurt',
    'chicken', 'beef', 'pork', 'lamb', 'fish', 'salmon', 'tuna', 'turkey', 'bacon', 'ham',
    'apple', 'banana', 'orange', 'tomato', 'potato', 'onion', 'avocado', 'berry', 'mango',
    'carrot', 'spinach', 'lettuce', 'broccoli', 'cucumber', 'pepper', 'garlic', 'celery',
    'aubergine', 'eggplant', 'courgette', 'zucchini', 'mushroom', 'asparagus', 'kale',
    'rice', 'pasta', 'flour', 'sugar', 'salt', 'oil', 'oats', 'cereal', 'noodle',
    'coffee', 'tea', 'juice', 'water', 'soda', 'milk',
    'crackers', 'chips', 'cookies', 'chocolate', 'snack', 'granola',
    'ketchup', 'mustard', 'mayo', 'sauce', 'vinegar', 'honey', 'jam', 'syrup',
    'soup', 'stock', 'broth', 'hummus', 'salsa',
    'canned', 'frozen', 'organic', 'fresh',
    // South Asian / Bangladeshi items
    'vermicelli', 'biscuit', 'ghee', 'lentil', 'dal', 'atta', 'maida',
    'mustard oil', 'hilsa', 'rui', 'pineapple', 'cucumber', 'brinjal',
    'bitter gourd', 'bottle gourd', 'pointed gourd', 'taro',
  ];
}
