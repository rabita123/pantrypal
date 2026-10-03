import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pantrypal/core/config/backend_config.dart';
import 'package:pantrypal/core/utils/grocery_ocr_parser.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/scan/data/ai_scan_client.dart';
import 'package:uuid/uuid.dart';

/// A meal idea from Leftover Rescue. It is a real [Recipe] so it can go
/// straight into the plan, be cooked, and update the pantry like any other.
class RescueIdea {
  final Recipe recipe;
  final String emoji;
  const RescueIdea(this.recipe, this.emoji);
}

/// Leftover Rescue: the user picks food that needs using, the AI suggests
/// three practical meals built around it.
class RescueService {
  static const _uuid = Uuid();

  static Future<List<RescueIdea>> ideas({
    required List<PantryItem> picked,
    required List<PantryItem> pantry,
    required int servings,
    http.Client? client,
  }) async {
    final owns = client == null;
    final c = client ?? http.Client();
    final http.Response res;
    try {
      res = await c
          .post(
            BackendConfig.function('rescue-ideas'),
            headers: BackendConfig.headers,
            body: jsonEncode({
              'picked': [
                for (final p in picked) {'name': p.name, 'daysLeft': p.daysUntilExpiry},
              ],
              'pantry': [
                for (final p in pantry)
                  if (!picked.any((x) => x.id == p.id)) {'name': p.name},
              ],
              'servings': servings,
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      throw BackendException.from(e);
    } finally {
      if (owns) c.close();
    }

    Map<String, dynamic> body;
    try {
      // Always UTF-8: `res.body` falls back to Latin-1 when the server omits a
      // charset, which garbles emoji and accented dish names.
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const BackendException('The idea service is unavailable right now. Please try again shortly.');
    }
    if (res.statusCode != 200) {
      throw BackendException((body['error'] as String?) ?? 'The idea service is unavailable right now.');
    }
    final text = body['result'] as String? ?? '';
    final ideas = parse(text);
    if (ideas.isEmpty) {
      throw const BackendException("Couldn't come up with ideas for that. Try picking a couple more foods.");
    }
    return ideas;
  }

  /// Turns the model's JSON into recipes, skipping anything malformed.
  static List<RescueIdea> parse(String text, {DateTime? now}) {
    final out = <RescueIdea>[];
    for (final m in JsonObjectStreamParser().feed(text)) {
      final name = (m['name'] as String?)?.trim() ?? '';
      final rawIngs = m['ingredients'];
      final rawSteps = m['steps'];
      if (name.isEmpty || rawIngs is! List || rawIngs.isEmpty) continue;

      final ings = <RecipeIngredient>[
        for (final i in rawIngs.whereType<Map>())
          if ((i['name'] as String?)?.trim().isNotEmpty ?? false)
            RecipeIngredient(
              name: (i['name'] as String).trim(),
              quantity: (i['quantity'] as num?)?.toDouble() ?? 1,
              unit: (i['unit'] as String?) ?? '',
              category: GroceryOcrParser.guessCategory(i['name'] as String),
            ),
      ];
      if (ings.isEmpty) continue;

      int? asInt(Object? v) => v is num && v > 0 ? v.round() : null;
      out.add(RescueIdea(
        Recipe(
          id: 'ai-${_uuid.v4()}',
          name: name.length > 60 ? name.substring(0, 60) : name,
          description: m['description'] as String?,
          servings: asInt(m['servings'])?.clamp(1, 12) ?? 2,
          prepMinutes: asInt(m['prepMinutes'])?.clamp(1, 180) ?? 10,
          cookMinutes: asInt(m['cookMinutes'])?.clamp(0, 240) ?? 20,
          ingredients: ings,
          steps: rawSteps is List ? rawSteps.whereType<String>().take(10).toList() : const [],
          dietaryTags: const {},
          cuisine: Cuisine.any,
          isFavorite: false,
          createdAt: now ?? DateTime.now(),
          kcalPerServing: asInt(m['kcalPerServing'])?.clamp(50, 2500),
          proteinPerServing: asInt(m['proteinPerServing'])?.clamp(0, 200),
        ),
        _emoji(m['emoji']),
      ));
      if (out.length == 3) break;
    }
    return out;
  }
}

/// One short emoji, or a pan when the model sent something else.
String _emoji(Object? v) {
  final s = (v is String) ? v.trim() : '';
  return s.isNotEmpty && s.length <= 8 && !RegExp(r'[A-Za-z0-9]').hasMatch(s) ? s : '🍳';
}
