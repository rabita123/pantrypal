import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';

class IngredientMatch {
  final String ingredientName;
  final bool found;
  final bool expiringSoon;

  const IngredientMatch({
    required this.ingredientName,
    required this.found,
    required this.expiringSoon,
  });
}

class CookTonightResult {
  final Recipe recipe;
  final List<IngredientMatch> matches;
  final int foundCount;
  final int totalCount;
  final int expiringCount;

  double get matchPercent => totalCount == 0 ? 0 : foundCount / totalCount;
  bool get canCookNow => matchPercent >= 0.8;

  const CookTonightResult({
    required this.recipe,
    required this.matches,
    required this.foundCount,
    required this.totalCount,
    required this.expiringCount,
  });
}

class CookTonightService {
  static List<CookTonightResult> match({
    required List<Recipe> recipes,
    required List<PantryItem> pantryItems,
  }) {
    final active = pantryItems.where((p) => p.isActive && p.expiryStatus != ExpiryStatus.expired).toList();
    final results = recipes.map((r) => _matchRecipe(r, active)).toList();

    results.sort((a, b) {
      // Sort: prioritise recipes that use expiring items, then by match %
      if (a.expiringCount != b.expiringCount) return b.expiringCount.compareTo(a.expiringCount);
      return b.matchPercent.compareTo(a.matchPercent);
    });

    return results.where((r) => r.matchPercent > 0).toList();
  }

  static CookTonightResult _matchRecipe(Recipe recipe, List<PantryItem> pantry) {
    final matches = recipe.ingredients.map((ing) {
      final found = pantry.firstWhere(
        (p) => _isMatch(ing.name, p.name),
        orElse: () => _sentinel,
      );
      final matched = found != _sentinel;
      final expiring = matched && found.expiryStatus == ExpiryStatus.expiringSoon;
      return IngredientMatch(ingredientName: ing.name, found: matched, expiringSoon: expiring);
    }).toList();

    return CookTonightResult(
      recipe: recipe,
      matches: matches,
      foundCount: matches.where((m) => m.found).length,
      totalCount: matches.length,
      expiringCount: matches.where((m) => m.expiringSoon).length,
    );
  }

  // Bidirectional word overlap — "chicken breast" matches "chicken", "tomatoes" matches "tomato"
  static bool _isMatch(String ingredient, String pantryName) {
    final a = _tokens(ingredient);
    final b = _tokens(pantryName);
    // Check if any meaningful token from either side appears in the other
    for (final token in a) {
      if (b.any((t) => t.contains(token) || token.contains(t))) return true;
    }
    return false;
  }

  static List<String> _tokens(String name) {
    const stop = {'a', 'an', 'the', 'of', 'or', 'and', 'with', 'in', 'to', 'for', 'fresh', 'large', 'small', 'medium'};
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !stop.contains(w))
        .map((w) => w.endsWith('s') && w.length > 4 ? w.substring(0, w.length - 1) : w)
        .toList();
  }

  // Sentinel object to avoid null (firstWhere orElse)
  static final _sentinel = PantryItem(
    id: '__sentinel__',
    name: '',
    category: FoodCategory.other,
    location: StorageLocation.pantry,
    quantity: 0,
    unit: '',
    expiryDate: DateTime(2099),
    addedDate: DateTime.now(),
    isConsumed: false,
    isWasted: false,
  );
}
