import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pantrypal/core/config/backend_config.dart';
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

/// Prefers the server's own error text, falling back to plain language.
String _serverMessage(http.Response response) {
  try {
    final body = jsonDecode(response.body);
    final error = (body is Map ? body['error'] : null) as String?;
    if (error != null && error.isNotEmpty) return error;
  } catch (_) {
    // Non-JSON body (a gateway HTML page, say) — fall through.
  }
  return 'The recipe service is unavailable right now (${response.statusCode}). '
      'Please try again shortly.';
}

class AIRecipeService {
  static Future<AIRecipe> generate(List<PantryItem> pantryItems) async {
    // Send items expiring within 7 days first, then the rest
    final sorted = [...pantryItems]
      ..sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

    final items = sorted.take(15).map((item) => {
      'name': item.name,
      'category': item.category.label,
      'daysLeft': item.daysUntilExpiry.clamp(0, 999),
    }).toList();

    final http.Response response;
    try {
      response = await http
          .post(
            BackendConfig.function('generate-recipe'),
            headers: BackendConfig.headers,
            body: jsonEncode({'items': items}),
          )
          .timeout(const Duration(seconds: 40));
    } catch (e) {
      throw BackendException.from(e);
    }

    if (response.statusCode != 200) {
      throw BackendException(_serverMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = data['result'] as String? ?? '';

    final match = RegExp(r'\{[\s\S]*\}').firstMatch(rawText);
    if (match == null) {
      throw const BackendException(
          "The kitchen came back with something we couldn't read. Try again.");
    }

    final json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
    return AIRecipe.fromJson(json);
  }
}
