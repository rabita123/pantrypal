import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/constants/starter_foods.dart';
import 'package:pantrypal/core/utils/quick_add.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/scan/presentation/pages/barcode_scanner_page.dart';
import 'package:pantrypal/features/scan/presentation/pages/fridge_scan_page.dart';
import 'package:pantrypal/features/scan/presentation/pages/scan_page.dart';
import 'package:pantrypal/features/scan/presentation/pages/starter_picker_page.dart';
import 'package:pantrypal/features/subscription/bloc/subscription_cubit.dart';
import 'package:pantrypal/features/subscription/presentation/paywall_gate.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';
import 'package:pantrypal/injection_container.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';

/// One place that runs every way of getting food into the pantry: checks the
/// allowance, opens the right screen, stores the result and reports back
/// exactly which items were added (empty when the user backed out).
class ScanLauncher {
  /// Receipt and fridge pages store their own items and pop the list.
  static Future<List<PantryItem>> receipt(BuildContext context) async {
    if (!await PaywallGate.ensureScanAllowed(context) || !context.mounted) return const [];
    final items = await Navigator.push<List<PantryItem>>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    return _finish(context, items, aiScan: true, method: 'receipt');
  }

  static Future<List<PantryItem>> fridge(BuildContext context) async {
    if (!await PaywallGate.ensureScanAllowed(context) || !context.mounted) return const [];
    final items = await Navigator.push<List<PantryItem>>(
      context,
      MaterialPageRoute(builder: (_) => const FridgeScanPage()),
    );
    return _finish(context, items, aiScan: true, method: 'fridge');
  }

  /// Barcode lookups cost nothing to run, so they are never limited.
  static Future<List<PantryItem>> barcode(BuildContext context) async {
    final item = await Navigator.push<PantryItem>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (item == null || !context.mounted) return const [];
    context.read<PantryBloc>().add(PantryAddItem(item));
    return _finish(context, [item], aiScan: false, method: 'barcode');
  }

  static Future<List<PantryItem>> tapPicker(BuildContext context, {String actionLabel = 'Add'}) async {
    final foods = await Navigator.push<List<StarterFood>>(
      context,
      MaterialPageRoute(builder: (_) => StarterPickerPage(actionLabel: actionLabel)),
    );
    if (foods == null || foods.isEmpty || !context.mounted) return const [];
    final items = foods.map((f) => QuickAdd.fromStarter(f)).toList();
    context.read<PantryBloc>().add(PantryAddItems(items));
    return _finish(context, items, aiScan: false, method: 'tap');
  }

  static Future<List<PantryItem>> typed(BuildContext context, String text) async {
    final items = QuickAdd.parse(text);
    if (items.isEmpty) return const [];
    context.read<PantryBloc>().add(PantryAddItems(items));
    return _finish(context, items, aiScan: false, method: 'typed');
  }

  static Future<List<PantryItem>> _finish(
    BuildContext context,
    List<PantryItem>? items, {
    required bool aiScan,
    required String method,
  }) async {
    if (items == null || items.isEmpty) return const [];
    Analytics.track('food_added', {'method': method, 'count': items.length});
    Analytics.instance.logOnce('first_food_added', {'method': method, 'count': items.length});
    final service = sl<SubscriptionService>();
    await service.markFoodAdded();
    if (aiScan) await service.incrementScanCount();
    if (context.mounted) context.read<SubscriptionCubit>().load();
    return items;
  }
}
