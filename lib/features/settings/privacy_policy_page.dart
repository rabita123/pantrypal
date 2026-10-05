import 'package:flutter/material.dart';
import 'package:pantrypal/core/theme/app_theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Last updated: October 2026',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted)),
          const SizedBox(height: 20),
          _section('What stays on your phone', isDark,
              'Your pantry, shopping list, recipes and preferences are stored on your device. We have no accounts and do not collect your name, email or contacts.'),
          _section('AI scans', isDark,
              'Only if you allow it: when you scan a receipt or fridge photo, that one photo is sent securely to Anthropic\'s Claude AI to identify the food, and the list of items comes back. Leftover rescue sends the names of the foods you pick. PantryPal does not store the photo or use it for anything else. You can turn AI off any time in Settings → Data & privacy; receipts are then read on your phone. Barcode lookups send only the barcode number to Open Food Facts.'),
          _section('Anonymous usage statistics', isDark,
              'To find what is confusing and fix it, the app records which steps are used (for example "scan finished" or "paywall opened") against a random ID created on first launch. This never includes your food, photos, name, email, device or advertising ID, or your location, and is not used to track you across other apps. You can turn it off any time in Settings → Data & privacy.'),
          _section('Camera & Photos', isDark,
              'Camera access is used to photograph receipts, your fridge, and barcodes. Photos are only used for the scan you asked for.'),
          _section('Notifications', isDark,
              'Local notifications are scheduled on your device to remind you about expiring items. No notification data leaves your device.'),
          _section('Third-Party Services', isDark,
              'PantryPal uses Google Fonts, which downloads font files from Google servers on first launch. No personal data is sent. See fonts.google.com/privacy for details.\n\n'
              'When you are offline, receipt text is read on your phone using Google ML Kit, with nothing sent anywhere. Subscriptions are handled by Apple and RevenueCat.'),
          _section('Data Storage', isDark,
              'All pantry, shopping, and recipe data is stored in a local SQLite database and SharedPreferences on your device. Uninstalling the app removes all data.'),
          _section('Children', isDark,
              'PantryPal does not knowingly collect data from children under 13.'),
          _section('Contact', isDark,
              'Questions about this policy? Contact us at: tasmin.saira@gmail.com'),
        ],
      ),
    );
  }

  Widget _section(String title, bool isDark, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkInk : AppColors.ink)),
          const SizedBox(height: 8),
          Text(body,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted)),
        ],
      ),
    );
  }
}
