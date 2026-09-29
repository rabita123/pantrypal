// The review prompt's whole risk is asking at the wrong time, so the gate is
// tested far more thoroughly than the prompt itself.

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:pantrypal/shared/services/review_service.dart';

import '../support/plugin_stubs.dart';

/// Stands in for the platform channel; records what was asked of StoreKit.
class FakeInAppReview implements InAppReview {
  bool available;
  int requestCount = 0;
  int listingCount = 0;
  Object? throwOnRequest;

  FakeInAppReview({this.available = true});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    requestCount++;
    if (throwOnRequest != null) throw throwOnRequest!;
  }

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {
    listingCount++;
  }
}

/// Drives the service to the exact point where a prompt is allowed.
Future<ReviewService> earned(FakeInAppReview fake) async {
  final s = ReviewService.withReview(fake);
  for (var i = 0; i < ReviewService.sessionsRequired; i++) {
    await s.recordSession();
  }
  for (var i = 0; i < ReviewService.happyMomentsRequired; i++) {
    await s.recordHappyMoment();
  }
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeInAppReview fake;

  setUp(() {
    stubSharedPreferences();
    fake = FakeInAppReview();
  });

  group('Earning the moment', () {
    test('a brand new user is never asked', () async {
      final s = ReviewService.withReview(fake);
      expect(await s.shouldCelebrate(), isFalse);
    });

    test('happy moments alone are not enough — sessions are required too',
        () async {
      final s = ReviewService.withReview(fake);
      for (var i = 0; i < 50; i++) {
        await s.recordHappyMoment();
      }
      expect(await s.shouldCelebrate(), isFalse,
          reason: 'a first-day user must not be interrupted, however active');
    });

    test('sessions alone are not enough — the user must have succeeded at something',
        () async {
      final s = ReviewService.withReview(fake);
      for (var i = 0; i < 50; i++) {
        await s.recordSession();
      }
      expect(await s.shouldCelebrate(), isFalse);
    });

    test('asks once both thresholds are met', () async {
      final s = await earned(fake);
      expect(await s.shouldCelebrate(), isTrue);
    });

    test('one moment short is still no', () async {
      final s = ReviewService.withReview(fake);
      for (var i = 0; i < ReviewService.sessionsRequired; i++) {
        await s.recordSession();
      }
      for (var i = 0; i < ReviewService.happyMomentsRequired - 1; i++) {
        await s.recordHappyMoment();
      }
      expect(await s.shouldCelebrate(), isFalse);
    });

    test('happy moments accumulate across calls', () async {
      final s = ReviewService.withReview(fake);
      expect(await s.recordHappyMoment(), 1);
      expect(await s.recordHappyMoment(), 2);
      expect(await s.recordHappyMoment(), 3);
    });
  });

  group('Not asking twice', () {
    test('goes quiet immediately after being shown', () async {
      final s = await earned(fake);
      await s.recordCelebrationShown();
      expect(await s.shouldCelebrate(), isFalse);
    });

    test('stays quiet through the cooldown even as moments pile up', () async {
      final now = DateTime(2026, 1, 1);
      final s = await earned(fake);
      await s.recordCelebrationShown(now: now);

      for (var i = 0; i < 20; i++) {
        await s.recordHappyMoment();
      }
      expect(
        await s.shouldCelebrate(now: now.add(ReviewService.cooldown - const Duration(days: 1))),
        isFalse,
      );
    });

    test('may ask again long afterwards, once freshly earned', () async {
      final now = DateTime(2026, 1, 1);
      final s = await earned(fake);
      await s.recordCelebrationShown(now: now);

      for (var i = 0; i < ReviewService.happyMomentsRequired; i++) {
        await s.recordHappyMoment();
      }
      expect(
        await s.shouldCelebrate(now: now.add(ReviewService.cooldown + const Duration(days: 1))),
        isTrue,
      );
    });

    test('"Not now" earns a longer silence than being ignored', () async {
      final now = DateTime(2026, 1, 1);
      final s = await earned(fake);
      await s.recordCelebrationShown(now: now);
      await s.recordDeclined();

      for (var i = 0; i < ReviewService.happyMomentsRequired; i++) {
        await s.recordHappyMoment();
      }
      // Past the ordinary cooldown, but not the decline cooldown.
      expect(
        await s.shouldCelebrate(now: now.add(ReviewService.cooldown + const Duration(days: 1))),
        isFalse,
      );
      expect(
        await s.shouldCelebrate(
            now: now.add(ReviewService.cooldownAfterDecline + const Duration(days: 1))),
        isTrue,
      );
    });

    test('a user who has rated is never asked again', () async {
      final s = await earned(fake);
      await s.requestNativeReview();

      for (var i = 0; i < 100; i++) {
        await s.recordHappyMoment();
      }
      expect(
        await s.shouldCelebrate(now: DateTime(2030)),
        isFalse,
        reason: 'asking someone who already reviewed is pure annoyance',
      );
    });
  });

  group('Platform handoff', () {
    test('does not offer the moment when StoreKit is unavailable', () async {
      fake.available = false;
      final s = await earned(fake);
      expect(await s.shouldCelebrate(), isFalse);
    });

    test('rating hands off to the native prompt exactly once', () async {
      final s = await earned(fake);
      await s.requestNativeReview();
      expect(fake.requestCount, 1);
    });

    test('never opens a store listing — the native sheet is the whole flow',
        () async {
      final s = await earned(fake);
      await s.requestNativeReview();
      expect(fake.listingCount, 0);
    });

    test('a StoreKit failure is swallowed, not thrown at the user', () async {
      fake.throwOnRequest = Exception('StoreKit unavailable');
      final s = await earned(fake);
      await expectLater(s.requestNativeReview(), completes);
    });

    test('skips the native call entirely when unavailable', () async {
      final s = await earned(fake);
      fake.available = false;
      await s.requestNativeReview();
      expect(fake.requestCount, 0);
    });
  });
}
