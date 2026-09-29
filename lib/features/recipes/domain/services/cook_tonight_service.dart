import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';

class IngredientMatch {
  final String ingredientName;
  final bool found;
  final bool expiringSoon;
  final bool isStaple;

  const IngredientMatch({
    required this.ingredientName,
    required this.found,
    required this.expiringSoon,
    this.isStaple = false,
  });
}

class CookTonightResult {
  final Recipe recipe;
  final List<IngredientMatch> matches;
  final int foundCount;
  final int totalCount;
  final int expiringCount;

  double get matchPercent => totalCount == 0 ? 0 : foundCount / totalCount;
  bool get canCookNow => totalCount > 0 && foundCount == totalCount;
  int get missingCount => totalCount - foundCount;

  /// Matches backed by an actual pantry item rather than an assumed staple.
  int get realFoundCount => matches.where((m) => m.found && !m.isStaple).length;

  /// Ingredients still to buy for this recipe.
  List<String> get missingNames =>
      matches.where((m) => !m.found).map((m) => m.ingredientName).toList();

  /// Higher is better. Using food that is about to go off matters most, but
  /// not at the price of a recipe you would have to shop half a store for.
  double get score =>
      expiringCount * 3 + matchPercent * 4 - missingCount * 0.75 + (canCookNow ? 2 : 0);

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

    results.sort((a, b) => b.score.compareTo(a.score));

    // A recipe only counts if something real in the pantry matches — assumed
    // staples alone (salt, water) don't make a suggestion.
    return results.where((r) => r.matchPercent > 0 && r.realFoundCount > 0).toList();
  }

  /// Things every kitchen is assumed to have; never listed as "missing".
  static const _staples = {
    'salt', 'sea salt', 'pepper', 'black pepper', 'water', 'ice',
    'oil', 'olive oil', 'vegetable oil', 'cooking oil', 'sunflower oil',
  };

  static bool isStaple(String ingredient) =>
      _staples.contains(ingredient.toLowerCase().trim());

  static CookTonightResult _matchRecipe(Recipe recipe, List<PantryItem> pantry) {
    final matches = recipe.ingredients.map((ing) {
      if (isStaple(ing.name)) {
        return IngredientMatch(ingredientName: ing.name, found: true, expiringSoon: false, isStaple: true);
      }
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

  /// Whether two food names refer to the same thing ("Tomatoes" ~ "tomato").
  static bool namesMatch(String a, String b) => _isMatch(a, b);

  // Token match: "chicken breast" matches "chicken", "tomatoes" matches "tomato"
  static bool _isMatch(String ingredient, String pantryName) {
    final a = _tokens(ingredient);
    final b = _tokens(pantryName);
    if (a.isEmpty || b.isEmpty) return false;
    return a.any((t) => b.contains(t));
  }

  static List<String> _tokens(String name) {
    // Stop words filtered AFTER stemming so plural/stemmed forms are also caught.
    // Generic descriptor words (sauce, powder, paste…) are stripped so that
    // "soy sauce" and "tomato sauce" don't falsely match via the word "sauce".
    const stop = {
      'a', 'an', 'the', 'of', 'or', 'and', 'with', 'in', 'to', 'for',
      'fresh', 'large', 'small', 'medium',
      'sauce', 'powder', 'paste', 'stock', 'juice', 'seed', 'flake', 'leaf',
    };
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .map(_singular)
        .where((w) => !stop.contains(w))
        .toList();
  }

  /// Reduces a word to its singular form so "Eggs" in the pantry satisfies a
  /// recipe calling for "Egg".
  ///
  /// Chopping a bare trailing "s" is not enough: it leaves "tomatoes" as
  /// "tomatoe" (never matching "tomato") and, with a minimum-length guard,
  /// skips short staples like "eggs" entirely.
  static String _singular(String w) {
    if (w.length < 4) return w; // "peas" is as short as this usefully goes
    // -ies → -y   (berries → berry, cherries → cherry)
    if (w.endsWith('ies') && w.length > 4) {
      return '${w.substring(0, w.length - 3)}y';
    }
    // -oes → -o   (tomatoes → tomato, potatoes → potato, mangoes → mango)
    if (w.endsWith('oes')) {
      return w.substring(0, w.length - 2);
    }
    // -ches / -shes / -sses / -xes / -zes → drop "es"
    //   (peaches → peach, dishes → dish, boxes → box)
    if (RegExp(r'(ch|sh|ss|x|z)es$').hasMatch(w)) {
      return w.substring(0, w.length - 2);
    }
    // Plain -s, but never -ss (glass, couscous stay whole)
    if (w.endsWith('s') && !w.endsWith('ss')) {
      return w.substring(0, w.length - 1);
    }
    return w;
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
