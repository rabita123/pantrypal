import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/subscription/bloc/subscription_cubit.dart';

class PaywallPage extends StatelessWidget {
  final bool isLimitReached;
  const PaywallPage({super.key, this.isLimitReached = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
      body: BlocConsumer<SubscriptionCubit, SubscriptionState>(
        listener: (context, state) {
          if (state is SubscriptionReady && state.isPremium) {
            Navigator.of(context).pop();
          }
          if (state is SubscriptionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.expired,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is SubscriptionLoading;

          return Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Go Premium',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkInk : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isLimitReached
                            ? "You've used all 3 free scans.\nUpgrade for unlimited scanning."
                            : "Unlock unlimited scanning, expiry alerts,\nand everything PantryPal has to offer.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _FeatureCard(isDark: isDark),
                      const SizedBox(height: 24),
                      if (isLoading)
                        const CircularProgressIndicator(color: AppColors.primary)
                      else
                        _PackageOptions(state: state, isDark: isDark),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => context.read<SubscriptionCubit>().restore(),
                        child: Text(
                          'Restore Purchases',
                          style: TextStyle(
                            color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _LegalFooter(isDark: isDark),
                    ],
                  ),
                ),
              ),
              // Close button last = rendered on top, taps not blocked by scroll view
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final bool isDark;
  const _FeatureCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.all_inclusive, 'Unlimited receipt scans'),
      (Icons.kitchen_outlined, 'Full pantry tracking'),
      (Icons.notifications_active_outlined, 'Expiry alerts'),
      (Icons.menu_book_outlined, 'Recipe management & suggestions'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: features
            .map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.primarySurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(f.$1, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        f.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkInk : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _PackageOptions extends StatefulWidget {
  final SubscriptionState state;
  final bool isDark;
  const _PackageOptions({required this.state, required this.isDark});

  @override
  State<_PackageOptions> createState() => _PackageOptionsState();
}

class _PackageOptionsState extends State<_PackageOptions> {
  Package? _selected;

  List<Package> _packages() {
    if (widget.state is! SubscriptionReady) return [];
    final offering = (widget.state as SubscriptionReady).offerings?.current;
    if (offering == null) return [];
    return offering.availablePackages;
  }

  String _label(Package p) {
    switch (p.packageType) {
      case PackageType.weekly:
        return 'Weekly';
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.annual:
        return 'Annual';
      default:
        return p.identifier;
    }
  }

  String _period(Package p) {
    switch (p.packageType) {
      case PackageType.weekly:
        return 'week';
      case PackageType.monthly:
        return 'month';
      case PackageType.annual:
        return 'year';
      default:
        return 'period';
    }
  }

  @override
  Widget build(BuildContext context) {
    final packages = _packages();

    if (packages.isEmpty) {
      return const Text(
        'No plans available. Check back soon.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
      );
    }

    // Auto-select first package if nothing selected yet
    _selected ??= packages.first;

    return Column(
      children: [
        ...packages.map((p) {
          final isSelected = _selected?.identifier == p.identifier;
          return GestureDetector(
            onTap: () => setState(() => _selected = p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarySurface : (widget.isDark ? AppColors.darkCard : AppColors.card),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : (widget.isDark ? AppColors.darkBorder : AppColors.border),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _label(p),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: widget.isDark ? AppColors.darkInk : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Auto-renews · Cancel anytime',
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${p.storeProduct.priceString} / ${_period(p)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppColors.primary : (widget.isDark ? AppColors.darkInk : AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _selected == null
                ? null
                : () => context.read<SubscriptionCubit>().purchase(_selected!),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text(
              'Subscribe',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalFooter extends StatelessWidget {
  final bool isDark;
  static const _privacyUrl = 'https://sites.google.com/view/pantrypal-app/privacy-policy';
  static const _termsUrl = 'https://sites.google.com/view/pantrypal-app/terms-of-service';

  const _LegalFooter({required this.isDark});

  Color get _mutedColor => isDark ? AppColors.darkInkMuted : AppColors.inkLight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Payment will be charged to your Apple ID at confirmation of purchase. '
          'Subscription automatically renews unless cancelled at least 24 hours '
          'before the end of the current period. Your account will be charged for '
          'renewal within 24 hours prior to the end of the current period. '
          'You can manage and cancel your subscriptions by going to your account '
          'settings in the App Store after purchase.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: _mutedColor, height: 1.5),
        ),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(fontSize: 11, color: _mutedColor),
            children: [
              TextSpan(
                text: 'Privacy Policy',
                style: TextStyle(
                  color: isDark ? AppColors.primary.withValues(alpha: 0.8) : AppColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    final uri = Uri.parse(_privacyUrl);
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
              ),
              const TextSpan(text: '  ·  '),
              TextSpan(
                text: 'Terms of Use',
                style: TextStyle(
                  color: isDark ? AppColors.primary.withValues(alpha: 0.8) : AppColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    final uri = Uri.parse(_termsUrl);
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
