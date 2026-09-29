import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the free plan includes — one place, so the paywall, Settings and the
/// gates can never disagree.
///
/// Free: everything in the core loop (manual / barcode / quick add, Use This
/// First, reminders, recipe matches, shopping list) plus a generous taste of
/// the two features that cost real money to run: AI photo scans and AI recipes.
class SubscriptionService {
  static const _scanCountKey = 'free_scan_count';
  static const _recipeWeekKey = 'ai_recipe_week';
  static const _recipeCountKey = 'ai_recipe_count';
  static const _launchCountKey = 'launch_count';
  static const _foodAddedKey = 'has_added_food';
  static const _softPaywallShownKey = 'soft_paywall_shown';

  /// AI photo scans (receipt or fridge) included for free, lifetime.
  static const freeScansAllowed = 5;

  /// AI rescue recipes included for free each week.
  static const freeRecipesPerWeek = 1;

  static final instance = SubscriptionService._();
  SubscriptionService._();

  // ── AI scan allowance ─────────────────────────────────────────────────────

  Future<int> get freeScanCount async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scanCountKey) ?? 0;
  }

  Future<bool> get hasFreeScanRemaining async {
    return (await freeScanCount) < freeScansAllowed;
  }

  Future<void> incrementScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_scanCountKey) ?? 0;
    await prefs.setInt(_scanCountKey, current + 1);
  }

  // ── AI recipe allowance (weekly) ──────────────────────────────────────────

  static String weekKey(DateTime d) {
    final monday = DateTime(d.year, d.month, d.day - (d.weekday - 1));
    return '${monday.year}-${monday.month}-${monday.day}';
  }

  Future<int> recipesUsedThisWeek({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_recipeWeekKey) != weekKey(now ?? DateTime.now())) return 0;
    return prefs.getInt(_recipeCountKey) ?? 0;
  }

  Future<bool> canGenerateRecipe({DateTime? now}) async {
    if (await isPremium()) return true;
    return (await recipesUsedThisWeek(now: now)) < freeRecipesPerWeek;
  }

  Future<void> recordRecipeGenerated({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = weekKey(now ?? DateTime.now());
    final used = prefs.getString(_recipeWeekKey) == key
        ? (prefs.getInt(_recipeCountKey) ?? 0)
        : 0;
    await prefs.setString(_recipeWeekKey, key);
    await prefs.setInt(_recipeCountKey, used + 1);
  }

  // ── Paywall timing ────────────────────────────────────────────────────────

  Future<int> recordLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt(_launchCountKey) ?? 0) + 1;
    await prefs.setInt(_launchCountKey, n);
    return n;
  }

  /// Call whenever food lands in the pantry; the offer is only ever made to
  /// someone who has already got something useful out of the app.
  Future<void> markFoodAdded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_foodAddedKey, true);
  }

  /// A single, gentle offer: on a later visit, after the user has food in the
  /// app. Never on first launch, never repeatedly.
  Future<bool> shouldShowSoftPaywall() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_softPaywallShownKey) ?? false) return false;
    if (!(prefs.getBool(_foodAddedKey) ?? false)) return false;
    if ((prefs.getInt(_launchCountKey) ?? 0) < 3) return false;
    return !(await isPremium());
  }

  Future<void> markSoftPaywallShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_softPaywallShownKey, true);
  }

  // ── RevenueCat ────────────────────────────────────────────────────────────

  Future<bool> isPremium() async {
    try {
      await Purchases.invalidateCustomerInfoCache();
      final info = await Purchases.getCustomerInfo();
      final activeKeys = info.entitlements.active.keys.toList();
      debugPrint('[SubscriptionService] active entitlements: $activeKeys');
      return info.entitlements.active.containsKey('pantryprn');
    } catch (e) {
      debugPrint('[SubscriptionService] isPremium error: $e');
      return false;
    }
  }

  Future<bool> canScan() async {
    if (await isPremium()) return true;
    return hasFreeScanRemaining;
  }

  Future<Offerings> fetchOfferings() => Purchases.getOfferings();

  Future<CustomerInfo> purchasePackage(Package package) =>
      Purchases.purchasePackage(package);

  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();
}
