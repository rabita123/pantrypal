import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decides *whether* to celebrate a happy moment and offer the review prompt.
///
/// Apple's own prompt is rate-limited to three appearances a year and may
/// silently show nothing, so the app must never depend on it appearing, never
/// tell the user it will, and never gate anything behind it. The gating here is
/// deliberately conservative: a request the user does not welcome is worse than
/// no request at all.
class ReviewService {
  static final instance = ReviewService._(InAppReview.instance);
  ReviewService._(this._review);

  /// Test seam — lets a fake stand in for the platform channel.
  @visibleForTesting
  ReviewService.withReview(this._review);

  final InAppReview _review;

  // ── Tuning ────────────────────────────────────────────────────────────────

  /// Positive actions required before the moment is offered at all.
  static const happyMomentsRequired = 5;

  /// Sessions required, so a first-day user is never interrupted.
  static const sessionsRequired = 3;

  /// Quiet period after any prompt, accepted or dismissed.
  static const cooldown = Duration(days: 120);

  /// Quiet period after the user says "Not now" — longer, because they
  /// already answered the question once.
  static const cooldownAfterDecline = Duration(days: 180);

  // ── Keys ──────────────────────────────────────────────────────────────────

  static const _kMoments = 'review_happy_moments';
  static const _kSessions = 'review_sessions';
  static const _kLastPromptAt = 'review_last_prompt_at';
  static const _kDeclined = 'review_declined';
  static const _kRated = 'review_completed';

  // ── Signals ───────────────────────────────────────────────────────────────

  /// Call once per app launch.
  Future<void> recordSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSessions, (prefs.getInt(_kSessions) ?? 0) + 1);
  }

  /// Call when the user does something that genuinely went well — using food
  /// before it expired, say. Returns the running count.
  Future<int> recordHappyMoment() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_kMoments) ?? 0) + 1;
    await prefs.setInt(_kMoments, next);
    return next;
  }

  // ── Decision ──────────────────────────────────────────────────────────────

  /// Whether a happy moment should be shown right now.
  Future<bool> shouldCelebrate({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();

    // Asked and answered — never ask this user again.
    if (prefs.getBool(_kRated) ?? false) return false;

    if ((prefs.getInt(_kSessions) ?? 0) < sessionsRequired) return false;
    if ((prefs.getInt(_kMoments) ?? 0) < happyMomentsRequired) return false;

    final lastMs = prefs.getInt(_kLastPromptAt);
    if (lastMs != null) {
      final declined = prefs.getBool(_kDeclined) ?? false;
      final wait = declined ? cooldownAfterDecline : cooldown;
      final since = (now ?? DateTime.now())
          .difference(DateTime.fromMillisecondsSinceEpoch(lastMs));
      if (since < wait) return false;
    }

    // Nothing to offer if the platform cannot show the prompt.
    return _review.isAvailable();
  }

  // ── Outcomes ──────────────────────────────────────────────────────────────

  /// The moment was shown. Starts the cooldown regardless of what follows, so
  /// an ignored sheet still counts as having asked.
  Future<void> recordCelebrationShown({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _kLastPromptAt, (now ?? DateTime.now()).millisecondsSinceEpoch);
    await prefs.setInt(_kMoments, 0);
  }

  /// The user chose "Not now".
  Future<void> recordDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDeclined, true);
  }

  /// The user asked to rate — hand off to Apple's native prompt.
  ///
  /// StoreKit decides whether anything actually appears; there is no callback
  /// and no way to know, which is why this returns nothing meaningful and the
  /// UI must not wait on a result.
  Future<void> requestNativeReview() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRated, true);
    await prefs.setBool(_kDeclined, false);
    try {
      if (await _review.isAvailable()) {
        await _review.requestReview();
      }
    } catch (e) {
      debugPrint('[ReviewService] requestReview failed: $e');
    }
  }

  @visibleForTesting
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [_kMoments, _kSessions, _kLastPromptAt, _kDeclined, _kRated]) {
      await prefs.remove(k);
    }
  }
}
