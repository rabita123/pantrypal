import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/core/utils/food_emoji.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

class PantryItemCard extends StatelessWidget {
  final PantryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onConsumed;
  final VoidCallback? onWasted;
  final VoidCallback? onDelete;
  final VoidCallback? onFreeze;

  const PantryItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onConsumed,
    this.onWasted,
    this.onDelete,
    this.onFreeze,
  });

  @override
  Widget build(BuildContext context) {
    final status = item.expiryStatus;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    switch (status) {
      case ExpiryStatus.fresh:
        statusColor = AppColors.fresh;
        statusBg = AppColors.freshSurface;
        statusIcon = Icons.check_circle_outline;
      case ExpiryStatus.expiringSoon:
        statusColor = AppColors.expiringSoon;
        statusBg = AppColors.expiringSoonSurface;
        statusIcon = Icons.timer_outlined;
      case ExpiryStatus.expired:
        statusColor = AppColors.expired;
        statusBg = AppColors.expiredSurface;
        statusIcon = Icons.warning_amber_outlined;
    }

    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onConsumed?.call(),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: Icons.check,
            label: 'Consumed',
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
          SlidableAction(
            onPressed: (_) => onWasted?.call(),
            backgroundColor: AppColors.expiringSoon,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Wasted',
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: status == ExpiryStatus.expiringSoon
                  ? AppColors.expiringSoon.withOpacity(0.4)
                  : status == ExpiryStatus.expired
                      ? AppColors.expired.withOpacity(0.4)
                      : isDark
                          ? AppColors.darkBorder
                          : AppColors.border,
              width: status == ExpiryStatus.fresh ? 1 : 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Color(item.category.colorValue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    foodEmoji(item.name, item.category),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkInk : AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            item.location.emoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.location.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          if (item.price != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '\$${item.price!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Expiry status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            _expiryShortLabel(item),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d').format(item.expiryDate),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkLight,
                      ),
                    ),
                    if (onFreeze != null &&
                        item.daysUntilExpiry <= 1 &&
                        item.location != StorageLocation.freezer) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onFreeze,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('❄️', style: TextStyle(fontSize: 11)),
                              SizedBox(width: 3),
                              Text(
                                'Freeze',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _expiryShortLabel(PantryItem item) {
    final days = item.daysUntilExpiry;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Today!';
    if (days == 1) return '1 day';
    return '$days days';
  }
}
