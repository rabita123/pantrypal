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
          Text('Last updated: May 2025',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted)),
          const SizedBox(height: 20),
          _section('What We Collect', isDark,
              'PantryPal stores all data locally on your device only. We do not collect, transmit, or share any personal data with third-party servers.\n\n'
              '• Pantry items and expiry dates\n'
              '• Shopping list entries\n'
              '• Recipe data\n'
              '• App preferences'),
          _section('Camera & Photos', isDark,
              'Camera access is used solely to photograph grocery receipts for on-device text recognition (OCR). Photos are processed locally and are never uploaded or stored permanently.'),
          _section('Notifications', isDark,
              'Local notifications are scheduled on your device to remind you about expiring items. No notification data leaves your device.'),
          _section('Third-Party Services', isDark,
              'PantryPal uses Google Fonts, which downloads font files from Google servers on first launch. No personal data is sent. See fonts.google.com/privacy for details.\n\n'
              'OCR text recognition is performed on-device using Google ML Kit with no data sent to external servers.'),
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
