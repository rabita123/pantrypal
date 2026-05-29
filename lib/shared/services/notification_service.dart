import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

class NotificationService {
  static final instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    ));
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          AppConstants.expiryChannelId,
          AppConstants.expiryChannelName,
          description: 'Alerts for food items expiring soon',
          importance: Importance.high,
        ));
    _initialized = true;
  }

  Future<void> scheduleExpiryReminder(PantryItem item) async {
    if (!_initialized) await init();
    // Remind 1 day before expiry
    final reminderDate = item.expiryDate.subtract(const Duration(days: 1));
    if (reminderDate.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        item.id.hashCode.abs() % 2147483647,
        '🥗 Use ${item.name} today!',
        'Expires tomorrow — use it before it goes to waste.',
        tz.TZDateTime.from(reminderDate, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.expiryChannelId,
            AppConstants.expiryChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelReminder(String itemId) async {
    await _plugin.cancel(itemId.hashCode.abs() % 2147483647);
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> showDailySummary(int expiringCount) async {
    if (!_initialized) await init();
    await _plugin.show(
      999999,
      '🛒 PantryPal Daily Summary',
      '$expiringCount item${expiringCount == 1 ? '' : 's'} expiring soon in your pantry.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.expiryChannelId,
          AppConstants.expiryChannelName,
          importance: Importance.defaultImportance,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
