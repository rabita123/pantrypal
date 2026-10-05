import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';

/// Explicit permission before anything is sent to the third-party AI
/// (App Store Review Guideline 5.1.2(i)).
///
/// AI receipt/fridge scans send the photo, and Leftover rescue sends the names
/// of the chosen foods, to Anthropic's Claude AI. Nothing is sent until the
/// user taps Allow; the choice can be changed any time in Settings.
class AiConsent {
  static const _key = 'ai_consent';
  static const privacyUrl = 'https://sites.google.com/view/pantrypal-app/privacy-policy';

  /// null = never asked, true = allowed, false = declined.
  static Future<bool?> current() async => (await SharedPreferences.getInstance()).getBool(_key);

  static Future<void> set(bool allowed) async {
    await (await SharedPreferences.getInstance()).setBool(_key, allowed);
    Analytics.track('ai_consent', {'granted': allowed});
  }

  /// True when AI may be used. Asks once if the user has never decided; asks
  /// again (rather than silently failing) if they said no before.
  static Future<bool> ensure(BuildContext context) async {
    if (await current() == true) return true;
    if (!context.mounted) return false;
    final allowed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ConsentSheet(),
    );
    if (allowed == null) return false; // dismissed: no decision recorded
    await set(allowed);
    return allowed;
  }
}

class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;

    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: TextStyle(fontSize: 14.5, color: ink, height: 1.4))),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Use AI to read your food?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink)),
              const SizedBox(height: 12),
              point(Icons.photo_camera_outlined,
                  'AI scans send the photo you take (receipt or fridge) to a third-party AI service to identify the food.'),
              point(Icons.restaurant_outlined,
                  'Leftover rescue sends the names of the foods you pick, to suggest meals.'),
              point(Icons.lock_outline,
                  'Nothing else is sent — no name, email or account. PantryPal does not store your photos.'),
              point(Icons.settings_outlined, 'You can change this any time in Settings → Data & privacy.'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => launchUrl(Uri.parse(AiConsent.privacyUrl)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('Privacy Policy'),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Allow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text("Don't allow", style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
