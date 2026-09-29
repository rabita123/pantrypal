import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/domain/services/cook_tonight_service.dart';

/// The few numbers and picks the whole app is built around: what to use first,
/// how much money that is, and what to cook with it.
class PantryInsights {
  /// Items that are expired or expire within 3 days, most urgent first.
  static List<PantryItem> useFirst(List<PantryItem> items) {
    final list = items
        .where((i) => i.isActive && i.daysUntilExpiry <= 3)
        .toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return list;
  }

  /// Value of food that is still good but running out of time.
  static double atRiskValue(List<PantryItem> items) => items
      .where((i) => i.isActive && i.daysUntilExpiry >= 0 && i.daysUntilExpiry <= 3)
      .fold<double>(0, (sum, i) => sum + i.estimatedValue);

  /// The single best "cook this tonight" pick, or null when nothing is both
  /// useful and realistic (cookable now, or at most two items short).
  static CookTonightResult? tonightPick(List<Recipe> recipes, List<PantryItem> items) {
    if (recipes.isEmpty || items.isEmpty) return null;
    final results = CookTonightService.match(recipes: recipes, pantryItems: items);
    for (final r in results) {
      if (r.canCookNow || r.missingCount <= 2) return r;
    }
    return null;
  }

  /// "$8" / "about $8" formatting for money that may be an estimate.
  static String money(double v, {bool approx = false}) {
    final s = v >= 10 ? v.round().toString() : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
    return '${approx ? '~' : ''}\$$s';
  }

  /// Short label like "Today", "Tomorrow", "3 days", "Expired".
  static String shortWhen(PantryItem item) {
    final d = item.daysUntilExpiry;
    if (d < 0) return d == -1 ? 'Expired yesterday' : 'Expired ${-d} days ago';
    if (d == 0) return 'Today';
    if (d == 1) return 'Tomorrow';
    return 'In $d days';
  }
}
