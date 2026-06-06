import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/data/recipe_seeds.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';

class RecipeRepository {
  static const _key = 'recipes_v1';
  static const _seededKey = 'recipes_seeded_v1';
  static const _kidsSeededKey = 'kids_recipes_seeded_v1';

  Future<void> seedIfEmpty() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seededKey) != true) {
      for (final recipe in kSeedRecipes) {
        await save(recipe);
      }
      await prefs.setBool(_seededKey, true);
    }
    // Seed kid recipes for both new and existing users
    if (prefs.getBool(_kidsSeededKey) != true) {
      for (final recipe in kKidSeedRecipes) {
        await save(recipe);
      }
      await prefs.setBool(_kidsSeededKey, true);
    }
  }

  Future<List<Recipe>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => _fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> save(Recipe recipe) async {
    final all = await getAll();
    final idx = all.indexWhere((r) => r.id == recipe.id);
    if (idx >= 0) {
      all[idx] = recipe;
    } else {
      all.add(recipe);
    }
    await _persist(all);
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((r) => r.id == id);
    await _persist(all);
  }

  Future<void> toggleFavorite(String id) async {
    final all = await getAll();
    final idx = all.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      all[idx] = all[idx].copyWith(isFavorite: !all[idx].isFavorite);
      await _persist(all);
    }
  }

  Future<void> _persist(List<Recipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(recipes.map(_toMap).toList()));
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> _toMap(Recipe r) => {
        'id': r.id,
        'name': r.name,
        'description': r.description,
        'servings': r.servings,
        'prepMinutes': r.prepMinutes,
        'cookMinutes': r.cookMinutes,
        'ingredients': r.ingredients.map(_ingToMap).toList(),
        'steps': r.steps,
        'dietaryTags': r.dietaryTags.map((t) => t.name).toList(),
        'cuisine': r.cuisine.name,
        'imageUrl': r.imageUrl,
        'isFavorite': r.isFavorite,
        'createdAt': r.createdAt.millisecondsSinceEpoch,
      };

  Map<String, dynamic> _ingToMap(RecipeIngredient i) => {
        'name': i.name,
        'quantity': i.quantity,
        'unit': i.unit,
        'category': i.category.name,
        'notes': i.notes,
      };

  Recipe _fromMap(Map<String, dynamic> m) => Recipe(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        servings: m['servings'] as int,
        prepMinutes: m['prepMinutes'] as int,
        cookMinutes: m['cookMinutes'] as int,
        ingredients: (m['ingredients'] as List<dynamic>)
            .map((e) => _ingFromMap(e as Map<String, dynamic>))
            .toList(),
        steps: List<String>.from(m['steps'] as List),
        dietaryTags: (m['dietaryTags'] as List<dynamic>)
            .map((e) => DietaryTag.fromString(e as String))
            .whereType<DietaryTag>()
            .toSet(),
        cuisine: Cuisine.fromString(m['cuisine'] as String),
        imageUrl: m['imageUrl'] as String?,
        isFavorite: m['isFavorite'] as bool,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      );

  RecipeIngredient _ingFromMap(Map<String, dynamic> m) => RecipeIngredient(
        name: m['name'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unit: m['unit'] as String,
        category: FoodCategory.fromString(m['category'] as String),
        notes: m['notes'] as String?,
      );
}
