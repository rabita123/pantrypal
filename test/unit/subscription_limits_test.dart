import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';

import '../support/plugin_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = SubscriptionService.instance;

  setUp(() => stubSharedPreferences());

  group('AI scan allowance', () {
    test('free scans run out after the allowance', () async {
      expect(await service.hasFreeScanRemaining, isTrue);
      for (var i = 0; i < SubscriptionService.freeScansAllowed; i++) {
        await service.incrementScanCount();
      }
      expect(await service.hasFreeScanRemaining, isFalse);
    });
  });

  group('weekly AI recipes', () {
    final monday = DateTime(2026, 3, 9); // a Monday
    final sunday = DateTime(2026, 3, 15);
    final nextMonday = DateTime(2026, 3, 16);

    test('week key is the same Monday-to-Sunday and changes after', () {
      expect(SubscriptionService.weekKey(monday), SubscriptionService.weekKey(sunday));
      expect(SubscriptionService.weekKey(monday), isNot(SubscriptionService.weekKey(nextMonday)));
    });

    test('usage counts within a week and resets in the next', () async {
      expect(await service.recipesUsedThisWeek(now: monday), 0);
      await service.recordRecipeGenerated(now: monday);
      expect(await service.recipesUsedThisWeek(now: sunday), 1);
      expect(await service.recipesUsedThisWeek(now: nextMonday), 0);
    });
  });

  group('paywall timing', () {
    test('is never offered before food has been added', () async {
      for (var i = 0; i < 5; i++) {
        await service.recordLaunch();
      }
      // isPremium() needs RevenueCat; the earlier gates must short-circuit first.
      expect(await service.shouldShowSoftPaywall(), isFalse);
    });

    test('is never offered on the first launches', () async {
      await service.markFoodAdded();
      await service.recordLaunch();
      expect(await service.shouldShowSoftPaywall(), isFalse);
    });

    test('is offered only once', () async {
      stubSharedPreferences({'soft_paywall_shown': true, 'has_added_food': true, 'launch_count': 9});
      expect(await service.shouldShowSoftPaywall(), isFalse);
    });
  });
}
