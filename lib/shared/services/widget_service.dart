import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

class WidgetService {
  static const _appGroupId = 'group.com.tsaira.receiptscanner';

  static Future<void> updateWidget({
    required List<PantryItem> expiringItems,
    required int totalItems,
  }) async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      final urgentItem =
          expiringItems.isNotEmpty ? expiringItems.first.name : '';
      final daysLeft = expiringItems.isNotEmpty
          ? expiringItems.first.expiryDate.difference(DateTime.now()).inDays
          : 0;
      await HomeWidget.saveWidgetData<int>('expiringCount', expiringItems.length);
      await HomeWidget.saveWidgetData<String>('urgentItem', urgentItem);
      await HomeWidget.saveWidgetData<int>('daysUntilExpiry', daysLeft);
      await HomeWidget.saveWidgetData<int>('totalItems', totalItems);
      await HomeWidget.updateWidget(iOSName: 'PantryPalWidget');
    } catch (e) {
      debugPrint('[WidgetService] update failed: $e');
    }
  }
}
