import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

class OpenFoodFactsProduct {
  final String name;
  final FoodCategory category;
  final String? imageUrl;
  final int estimatedExpiryDays;

  const OpenFoodFactsProduct({
    required this.name,
    required this.category,
    this.imageUrl,
    required this.estimatedExpiryDays,
  });
}

class OpenFoodFactsService {
  static Future<OpenFoodFactsProduct?> lookup(String barcode) async {
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode'
        '?fields=product_name,categories_tags,image_front_small_url',
      );
      final response = await http.get(uri, headers: {'User-Agent': 'PantryPal/1.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 1) return null;

      final product = data['product'] as Map<String, dynamic>;
      final name = (product['product_name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return null;

      final tags = (product['categories_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      return OpenFoodFactsProduct(
        name: name,
        category: _mapCategory(tags),
        imageUrl: product['image_front_small_url'] as String?,
        estimatedExpiryDays: _estimateExpiry(tags),
      );
    } catch (_) {
      return null;
    }
  }

  static FoodCategory _mapCategory(List<String> tags) {
    final joined = tags.join(' ').toLowerCase();
    if (_has(joined, ['milk', 'dairy', 'cheese', 'yogurt', 'butter', 'cream', 'egg'])) {
      return FoodCategory.dairy;
    }
    if (_has(joined, ['meat', 'beef', 'chicken', 'pork', 'fish', 'seafood', 'lamb', 'poultry'])) {
      return FoodCategory.meat;
    }
    if (_has(joined, ['vegetable', 'veggie', 'salad', 'fruit', 'produce', 'fresh'])) {
      return FoodCategory.vegetables;
    }
    if (_has(joined, ['juice', 'beverage', 'drink', 'soda', 'water', 'tea', 'coffee'])) {
      return FoodCategory.beverages;
    }
    if (_has(joined, ['bread', 'pasta', 'rice', 'grain', 'cereal', 'flour', 'oat', 'noodle'])) {
      return FoodCategory.grains;
    }
    if (_has(joined, ['snack', 'chip', 'crisp', 'biscuit', 'cookie', 'cracker', 'candy', 'chocolate'])) {
      return FoodCategory.snacks;
    }
    if (_has(joined, ['sauce', 'condiment', 'spice', 'oil', 'vinegar', 'dressing', 'ketchup', 'mustard'])) {
      return FoodCategory.condiments;
    }
    if (_has(joined, ['frozen', 'ice cream', 'freeze'])) {
      return FoodCategory.frozen;
    }
    return FoodCategory.other;
  }

  static int _estimateExpiry(List<String> tags) {
    final joined = tags.join(' ').toLowerCase();
    if (_has(joined, ['fresh', 'meat', 'fish', 'seafood'])) return 3;
    if (_has(joined, ['dairy', 'milk', 'yogurt'])) return 7;
    if (_has(joined, ['vegetable', 'fruit', 'produce'])) return 7;
    if (_has(joined, ['bread', 'bakery'])) return 5;
    if (_has(joined, ['frozen'])) return 90;
    if (_has(joined, ['snack', 'chip', 'biscuit', 'cereal'])) return 180;
    if (_has(joined, ['sauce', 'condiment', 'oil'])) return 365;
    return 30;
  }

  static bool _has(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));
}
