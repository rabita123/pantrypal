import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/features/subscription/bloc/subscription_cubit.dart';
import 'package:pantrypal/features/subscription/presentation/paywall_page.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';
import 'package:pantrypal/injection_container.dart';

/// The only places the paywall is allowed to appear: when the user reaches a
/// Premium limit, on their own request, or once as a gentle later offer.
class PaywallGate {
  static Future<void> show(
    BuildContext context, {
    PaywallReason reason = PaywallReason.general,
  }) async {
    final cubit = context.read<SubscriptionCubit>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BlocProvider.value(value: cubit, child: PaywallPage(reason: reason)),
      ),
    );
    cubit.load();
  }

  /// True when an AI photo scan may go ahead; otherwise shows the paywall.
  static Future<bool> ensureScanAllowed(BuildContext context) async {
    if (await sl<SubscriptionService>().canScan()) return true;
    if (context.mounted) await show(context, reason: PaywallReason.scanLimit);
    return false;
  }

  /// True when an AI recipe may be generated; otherwise shows the paywall.
  static Future<bool> ensureRecipeAllowed(BuildContext context) async {
    if (await sl<SubscriptionService>().canGenerateRecipe()) return true;
    if (context.mounted) await show(context, reason: PaywallReason.recipeLimit);
    return false;
  }
}
