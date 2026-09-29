import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/domain/services/pantry_insights.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/widgets/add_food_sheet.dart';
import 'package:pantrypal/features/pantry/presentation/widgets/add_item_dialog.dart';
import 'package:pantrypal/features/scan/scan_launcher.dart';
import 'package:pantrypal/shared/widgets/added_summary.dart';

/// "Add food" from anywhere: pick a way, do it, and see what it means.
class AddFlow {
  static Future<void> start(BuildContext context) async {
    final choice = await AddFoodSheet.show(context);
    if (choice == null || !context.mounted) return;
    await _perform(context, choice);
  }

  /// Jump straight to one way of adding, skipping the picker sheet.
  static Future<void> run(BuildContext context, AddKind kind) =>
      _perform(context, AddChoice(kind));

  static Future<void> _perform(BuildContext context, AddChoice choice) async {
    List<PantryItem> added;
    switch (choice.kind) {
      case AddKind.receipt:
        added = await ScanLauncher.receipt(context);
      case AddKind.fridge:
        added = await ScanLauncher.fridge(context);
      case AddKind.barcode:
        added = await ScanLauncher.barcode(context);
      case AddKind.tap:
        added = await ScanLauncher.tapPicker(context);
      case AddKind.typed:
        added = await ScanLauncher.typed(context, choice.text);
      case AddKind.manual:
        final item = await showModalBottomSheet<PantryItem>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const AddItemDialog(),
        );
        if (item == null || !context.mounted) return;
        context.read<PantryBloc>().add(PantryAddItem(item));
        added = [item];
    }
    if (added.isEmpty || !context.mounted) return;

    if (added.length == 1) {
      final item = added.single;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Added ${item.name} · ${PantryInsights.shortWhen(item).toLowerCase()}'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
        ));
    } else {
      await AddedSummarySheet.show(context, added);
    }
  }
}
