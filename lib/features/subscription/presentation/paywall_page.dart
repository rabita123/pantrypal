import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/subscription/bloc/subscription_cubit.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';

/// Why the paywall is being shown — the headline speaks to that moment.
enum PaywallReason { general, scanLimit, recipeLimit }

class PaywallPage extends StatelessWidget {
  final PaywallReason reason;
  const PaywallPage({super.key, this.reason = PaywallReason.general});

  String get _headline => switch (reason) {
        PaywallReason.scanLimit => "You've used your ${SubscriptionService.freeScansAllowed} free scans",
        PaywallReason.recipeLimit => 'Want another rescue recipe?',
        PaywallReason.general => 'Stop throwing money in the bin',
      };

  String get _subline => switch (reason) {
        PaywallReason.scanLimit =>
          'Keep filling your pantry from a receipt or fridge photo in seconds.',
        PaywallReason.recipeLimit =>
          'The free plan includes ${SubscriptionService.freeRecipesPerWeek} AI recipe a week. Premium makes them unlimited.',
        PaywallReason.general =>
          'Fill your pantry from a photo and get a recipe for whatever is about to expire.',
      };

  /// Money currently at risk in the user's own pantry — the honest reason to
  /// subscribe. Null when there is nothing to show.
  double? _atRisk(BuildContext context) {
    final state = context.read<PantryBloc>().state;
    if (state is! PantryLoaded) return null;
    final total = state.allItems
        .where((i) => i.expiryStatus == ExpiryStatus.expiringSoon)
        .fold<double>(0, (sum, i) => sum + i.estimatedValue);
    return total >= 1 ? total : null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;
    final atRisk = _atRisk(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
      body: BlocConsumer<SubscriptionCubit, SubscriptionState>(
        listener: (context, state) {
          if (state is SubscriptionReady && state.isPremium) {
            Navigator.of(context).pop();
          }
          if (state is SubscriptionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.expired),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is SubscriptionLoading;

          return Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.white, size: 34),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _headline,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink, height: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subline,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: muted, height: 1.5),
                      ),
                      if (atRisk != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.expiringSoonSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'You have about \$${atRisk.toStringAsFixed(0)} of food to use soon',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.expiringSoon,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _BenefitCard(isDark: isDark),
                      const SizedBox(height: 20),
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      else
                        _PackageOptions(state: state, isDark: isDark),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Not now', style: TextStyle(color: muted, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      TextButton(
                        onPressed: isLoading ? null : () => context.read<SubscriptionCubit>().restore(),
                        child: Text('Restore Purchases', style: TextStyle(color: muted, fontSize: 12)),
                      ),
                      const SizedBox(height: 4),
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
                      color: muted,
                      tooltip: 'Close',
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

/// Only what Premium actually unlocks — nothing that is free anyway.
class _BenefitCard extends StatelessWidget {
  final bool isDark;
  const _BenefitCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    const benefits = [
      (Icons.document_scanner_outlined, 'Unlimited receipt & fridge scans', 'Fill your pantry in seconds, every shop'),
      (Icons.auto_awesome_outlined, 'Unlimited AI rescue recipes', 'A dinner idea for whatever expires next'),
    ];
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          for (final b in benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                    child: Icon(b.$1, size: 19, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink)),
                        const SizedBox(height: 1),
                        Text(b.$3, style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Expiry reminders, Use This First, recipes and your shopping list stay free.',
                    style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  static int _rank(Package p) => switch (p.packageType) {
        PackageType.annual => 0,
        PackageType.monthly => 1,
        PackageType.weekly => 2,
        _ => 3,
      };

  List<Package> _packages() {
    if (widget.state is! SubscriptionReady) return [];
    final offering = (widget.state as SubscriptionReady).offerings?.current;
    if (offering == null) return [];
    return [...offering.availablePackages]..sort((a, b) => _rank(a).compareTo(_rank(b)));
  }

  String _label(Package p) => switch (p.packageType) {
        PackageType.weekly => 'Weekly',
        PackageType.monthly => 'Monthly',
        PackageType.annual => 'Yearly',
        _ => p.identifier,
      };

  String _period(Package p) => switch (p.packageType) {
        PackageType.weekly => 'week',
        PackageType.monthly => 'month',
        PackageType.annual => 'year',
        _ => 'period',
      };

  /// Free-trial length in days, or null when the plan has no free trial.
  int? _trialDays(Package p) {
    final intro = p.storeProduct.introductoryPrice;
    if (intro == null || intro.price != 0) return null;
    final n = intro.periodNumberOfUnits * (intro.cycles < 1 ? 1 : intro.cycles);
    return switch (intro.periodUnit) {
      PeriodUnit.day => n,
      PeriodUnit.week => n * 7,
      PeriodUnit.month => n * 30,
      PeriodUnit.year => n * 365,
      _ => null,
    };
  }

  String? _perMonth(Package p) {
    if (p.packageType != PackageType.annual) return null;
    try {
      return NumberFormat.simpleCurrency(name: p.storeProduct.currencyCode)
          .format(p.storeProduct.price / 12);
    } catch (_) {
      return null;
    }
  }

  /// "Save 60%" for the yearly plan versus paying monthly.
  String? _saving(Package p, List<Package> all) {
    if (p.packageType != PackageType.annual) return null;
    final monthly = all.where((x) => x.packageType == PackageType.monthly).firstOrNull;
    if (monthly == null || monthly.storeProduct.price <= 0) return null;
    final pct = (1 - p.storeProduct.price / (monthly.storeProduct.price * 12)) * 100;
    return pct >= 10 ? 'Save ${pct.round()}%' : null;
  }

  @override
  Widget build(BuildContext context) {
    final packages = _packages();
    final isDark = widget.isDark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;

    if (packages.isEmpty) {
      return Text(
        'Plans are unavailable right now. Check your connection and try again.',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted, fontSize: 13),
      );
    }

    // Yearly first and pre-selected: the plan that is best for the user is
    // also the one that sustains the app.
    _selected ??= packages.first;
    final selected = packages.firstWhere(
      (p) => p.identifier == _selected!.identifier,
      orElse: () => packages.first,
    );
    final trial = _trialDays(selected);

    return Column(
      children: [
        ...packages.map((p) {
          final isSelected = selected.identifier == p.identifier;
          final saving = _saving(p, packages);
          final perMonth = _perMonth(p);
          final planTrial = _trialDays(p);
          return GestureDetector(
            onTap: () {
              Analytics.track('paywall_plan_selected', {'plan': p.packageType.name});
              setState(() => _selected = p);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarySurface : (isDark ? AppColors.darkCard : AppColors.card),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? AppColors.primary : muted,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_label(p), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isSelected ? AppColors.primaryDark : ink)),
                            if (saving != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                                child: Text(saving, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                            ],
                          ],
                        ),
                        if (planTrial != null || perMonth != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (planTrial != null) '$planTrial-day free trial',
                              if (perMonth != null) '$perMonth / month',
                            ].join(' · '),
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '${p.storeProduct.priceString} / ${_period(p)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isSelected ? AppColors.primary : ink),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              Analytics.track('paywall_cta_tapped', {'plan': selected.packageType.name, 'trial': trial != null});
              context.read<SubscriptionCubit>().purchase(selected);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              trial != null ? 'Start $trial-day free trial' : 'Continue',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          trial != null
              ? 'Then ${selected.storeProduct.priceString} / ${_period(selected)}. Cancel anytime in App Store settings.'
              : 'Cancel anytime in App Store settings.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: muted),
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
