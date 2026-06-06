import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static const _scanCountKey = 'free_scan_count';
  static const _freeScansAllowed = 1;

  static final instance = SubscriptionService._();
  SubscriptionService._();

  // ── Scan counter ──────────────────────────────────────────────────────────

  Future<int> get freeScanCount async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scanCountKey) ?? 0;
  }

  Future<bool> get hasFreeScanRemaining async {
    return (await freeScanCount) < _freeScansAllowed;
  }

  Future<void> incrementScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_scanCountKey) ?? 0;
    await prefs.setInt(_scanCountKey, current + 1);
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
