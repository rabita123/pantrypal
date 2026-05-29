import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/core/utils/database_helper.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/settings/privacy_policy_page.dart';
import 'package:pantrypal/features/subscription/bloc/subscription_cubit.dart';
import 'package:pantrypal/features/subscription/presentation/paywall_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // TODO: replace with real URLs before App Store submission
  static const _termsUrl = 'https://yoursite.com/terms';
  static const _contactEmail = 'tasmin.saira@gmail.com';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Subscription ────────────────────────────────────────────────
          _SectionHeader(label: 'Subscription', isDark: isDark),
          _SubscriptionCard(isDark: isDark),
          const SizedBox(height: 8),

          // ── Legal ───────────────────────────────────────────────────────
          _SectionHeader(label: 'Legal', isDark: isDark),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
            ),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            label: 'Terms of Use',
            isDark: isDark,
            onTap: () async {
              final uri = Uri.parse(_termsUrl);
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
          ),
          const SizedBox(height: 8),

          // ── Data ────────────────────────────────────────────────────────
          _SectionHeader(label: 'Data', isDark: isDark),
          _SettingsTile(
            icon: Icons.delete_outline,
            label: 'Delete All Data',
            isDark: isDark,
            destructive: true,
            onTap: () => _confirmDeleteData(context, isDark),
          ),
          const SizedBox(height: 8),

          // ── Support ─────────────────────────────────────────────────────
          _SectionHeader(label: 'Support', isDark: isDark),
          _SettingsTile(
            icon: Icons.mail_outline,
            label: 'Contact Us',
            subtitle: _contactEmail,
            isDark: isDark,
            onTap: () async {
              final uri = Uri(scheme: 'mailto', path: _contactEmail);
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
          ),
          const SizedBox(height: 8),

          // ── About ───────────────────────────────────────────────────────
          _SectionHeader(label: 'About', isDark: isDark),
          _SettingsTile(
            icon: Icons.info_outline,
            label: 'Version',
            subtitle: '1.0.0',
            isDark: isDark,
            showChevron: false,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteData(BuildContext context, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete All Data?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkInk : AppColors.ink,
          ),
        ),
        content: Text(
          'This will permanently remove all pantry items, shopping lists, and reset your scan count. This cannot be undone.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.expired, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await DatabaseHelper.instance.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('free_scan_count');

    if (!context.mounted) return;
    context.read<PantryBloc>().add(PantryLoad());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All data deleted.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

// ── Subscription card ─────────────────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  final bool isDark;
  const _SubscriptionCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, state) {
        final isPremium = state is SubscriptionReady && state.isPremium;
        final scansUsed = state is SubscriptionReady ? state.scansUsed : 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isPremium
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isPremium ? null : (isDark ? AppColors.darkCard : AppColors.card),
            borderRadius: BorderRadius.circular(16),
            border: isPremium
                ? null
                : Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: isPremium ? _PremiumBadge() : _FreePlanInfo(isDark: isDark, scansUsed: scansUsed, context: context),
        );
      },
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.workspace_premium, color: Colors.white, size: 28),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Premium Active', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            SizedBox(height: 2),
            Text('Unlimited scans & features', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ],
    );
  }
}

class _FreePlanInfo extends StatelessWidget {
  final bool isDark;
  final int scansUsed;
  final BuildContext context;
  const _FreePlanInfo({required this.isDark, required this.scansUsed, required this.context});

  @override
  Widget build(BuildContext ctx) {
    final cubit = ctx.read<SubscriptionCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_outline, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted, size: 20),
            const SizedBox(width: 8),
            Text(
              'Free Plan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkInk : AppColors.ink,
              ),
            ),
            const Spacer(),
            Text(
              '$scansUsed / 1 scan used',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              ctx,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => BlocProvider.value(value: cubit, child: const PaywallPage()),
              ),
            ),
            icon: const Icon(Icons.workspace_premium, size: 18),
            label: const Text('Upgrade to Premium', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => ctx.read<SubscriptionCubit>().restore(),
            style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            child: Text(
              'Restore Purchases',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDark;
  final bool destructive;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.isDark,
    this.subtitle,
    this.destructive = false,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = destructive
        ? AppColors.expired
        : (isDark ? AppColors.darkInk : AppColors.ink);
    final iconColor = destructive
        ? AppColors.expired
        : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 22),
        title: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: labelColor)),
        subtitle: subtitle != null
            ? Text(subtitle!, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted))
            : null,
        trailing: showChevron
            ? Icon(Icons.chevron_right, color: isDark ? AppColors.darkInkMuted : AppColors.inkLight, size: 20)
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
