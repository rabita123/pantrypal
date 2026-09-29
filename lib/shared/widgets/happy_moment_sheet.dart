import 'package:flutter/material.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/shared/services/review_service.dart';

/// A warm acknowledgement of something the user did well, with a quiet offer
/// to leave a review.
///
/// Deliberately *not* a rating interface: there are no stars and no score to
/// pick. Choosing "Rate the App" hands straight off to Apple's native prompt,
/// which is the only place a rating is ever given.
class HappyMomentSheet extends StatelessWidget {
  final String title;
  final String message;

  const HappyMomentSheet({
    super.key,
    this.title = "You're doing great! 💛",
    this.message = "Enjoying the app? We'd love your feedback.",
  });

  /// Shows the moment if — and only if — it has been earned.
  ///
  /// Safe to call from anywhere a positive action completes; it returns
  /// without doing anything when the thresholds are not met.
  static Future<void> maybeShow(
    BuildContext context, {
    ReviewService? service,
    String? title,
    String? message,
  }) async {
    final reviews = service ?? ReviewService.instance;
    if (!await reviews.shouldCelebrate()) return;
    if (!context.mounted) return;

    await reviews.recordCelebrationShown();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HappyMomentSheet(
        title: title ?? "You're doing great! 💛",
        message: message ?? "Enjoying the app? We'd love your feedback.",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        // Scrollable so the sheet degrades gracefully in a constrained host —
        // a short screen, large accessibility text, or a caller that did not
        // ask for a scroll-controlled sheet.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('🌱', style: TextStyle(fontSize: 34)),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: isDark ? AppColors.darkInk : AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await ReviewService.instance.requestNativeReview();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Rate the App',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await ReviewService.instance.recordDeclined();
                },
                child: Text(
                  'Not now',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
