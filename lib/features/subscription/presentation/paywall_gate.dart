import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/features/subscription/bloc/subscription_cubit.dart';
import 'package:pantrypal/features/subscription/presentation/paywall_page.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';
import 'package:pantrypal/injection_container.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';

/// The only places the paywall is allowed to appear: when the user reaches a
/// Premium limit, on their own request, or once as a gentle later offer.
class PaywallGate {
  static Future<void> show(
    BuildContext context, {
    PaywallReason reason = PaywallReason.general,
  }) async {
    final cubit = context.read<SubscriptionCubit>();
    final opened = DateTime.now();
    Analytics.track('paywall_shown', {'reason': reason});
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BlocProvider.value(value: cubit, child: PaywallPage(reason: reason)),
      ),
    );
    final state = cubit.state;
    Analytics.track('paywall_closed', {
      'reason': reason,
      'seconds': DateTime.now().difference(opened).inSeconds,
      'premium': state is SubscriptionReady && state.isPremium,
    });
    Analytics.instance.flush();
    cubit.load();
  }

  /// True when an AI photo scan may go ahead; otherwise shows the paywall.
  static Future<bool> ensureScanAllowed(BuildContext context) async {
    if (await sl<SubscriptionService>().canScan()) return true;
    Analytics.track('limit_hit', {'feature': 'scan'});
    if (context.mounted) await show(context, reason: PaywallReason.scanLimit);
    return false;
  }

  /// True when an AI recipe may be generated; otherwise shows the paywall.
  static Future<bool> ensureRecipeAllowed(BuildContext context) async {
    if (await sl<SubscriptionService>().canGenerateRecipe()) return true;
    Analytics.track('limit_hit', {'feature': 'recipe'});
    if (context.mounted) await show(context, reason: PaywallReason.recipeLimit);
    return false;
  }
}
