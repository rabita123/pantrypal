import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

class AIRecipe {
  final String name;
  final String description;
  final String emoji;
  final String prepTime;
  final String cookTime;
  final int servings;
  final List<String> usesExpiring;
  final List<({String item, String amount})> ingredients;
  final List<String> steps;
  final String tip;

  const AIRecipe({
    required this.name,
    required this.description,
    required this.emoji,
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    required this.usesExpiring,
    required this.ingredients,
    required this.steps,
    required this.tip,
  });

  factory AIRecipe.fromJson(Map<String, dynamic> j) {
    return AIRecipe(
      name: j['name'] as String? ?? 'Chef\'s Special',
      description: j['description'] as String? ?? '',
      emoji: j['emoji'] as String? ?? '🍳',
      prepTime: j['prepTime'] as String? ?? '?',
      cookTime: j['cookTime'] as String? ?? '?',
      servings: (j['servings'] as num?)?.toInt() ?? 2,
      usesExpiring: (j['usesExpiring'] as List?)?.cast<String>() ?? [],
      ingredients: ((j['ingredients'] as List?) ?? []).map((i) {
        final m = i as Map<String, dynamic>;
        return (item: m['item'] as String? ?? '', amount: m['amount'] as String? ?? '');
      }).toList(),
      steps: (j['steps'] as List?)?.cast<String>() ?? [],
      tip: j['tip'] as String? ?? '',
    );
  }
}

class AIRecipeService {
  static const _supabaseUrl = 'https://hwkaxobdmyiyodtgrpio.supabase.co';
  static const _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3a2F4b2JkbXlpeW9kdGdycGlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyMjEyNjcsImV4cCI6MjA5NTc5NzI2N30.naKIQOSgMjP_-yM5fiNpiwpkSB2SuNHha9uVSTJF4Ug';

  static Future<AIRecipe> generate(List<PantryItem> pantryItems) async {
    // Send items expiring within 7 days first, then the rest
    final sorted = [...pantryItems]
      ..sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

    final items = sorted.take(15).map((item) => {
      'name': item.name,
      'category': item.category.label,
      'daysLeft': item.daysUntilExpiry.clamp(0, 999),
    }).toList();

    final response = await http.post(
      Uri.parse('$_supabaseUrl/functions/v1/generate-recipe'),
      headers: {
        'Authorization': 'Bearer $_supabaseAnonKey',
        'apikey': _supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'items': items}),
    ).timeout(const Duration(seconds: 40));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Server error ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = data['result'] as String? ?? '';

    final match = RegExp(r'\{[\s\S]*\}').firstMatch(rawText);
    if (match == null) throw Exception('Could not parse recipe from AI response');

    final json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
    return AIRecipe.fromJson(json);
  }
}
