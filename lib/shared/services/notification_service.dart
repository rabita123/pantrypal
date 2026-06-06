import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

@pragma('vm:entry-point')
void _onBackgroundTap(NotificationResponse _) {}

class NotificationService {
  static final instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Set this to handle a notification tap — switches the app to the Recipes tab.
  static VoidCallback? onNotificationTap;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
      onDidReceiveNotificationResponse: (_) => onNotificationTap?.call(),
      onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          AppConstants.expiryChannelId,
          AppConstants.expiryChannelName,
          description: 'Alerts for food items expiring soon',
          importance: Importance.high,
        ));
    // Explicitly request iOS permission
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  static int _instantId = 111100;

  /// Fires an instant notification right now — for demos and testing.
  Future<void> showInstant({required String title, required String body}) async {
    if (!_initialized) await init();
    await _plugin.show(
      _instantId++,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.expiryChannelId,
          AppConstants.expiryChannelName,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
    );
  }

  Future<void> scheduleExpiryReminder(PantryItem item) async {
    if (!_initialized) await init();
    final baseId = item.id.hashCode.abs() % 100000000;

    // Always fire at 9:00 AM on the reminder day — not at the random time the item was added
    tz.TZDateTime at9am(DateTime date) {
      final d = tz.TZDateTime(tz.local, date.year, date.month, date.day, 9, 0);
      // If 9am today has already passed, shift to tomorrow's 9am
      return d.isBefore(tz.TZDateTime.now(tz.local)) ? d.add(const Duration(days: 1)) : d;
    }

    // 2 days before expiry at 9am
    final twoDayDate = item.expiryDate.subtract(const Duration(days: 2));
    final twoDayAt9 = at9am(twoDayDate);
    if (twoDayAt9.isAfter(tz.TZDateTime.now(tz.local))) {
      await _plugin.zonedSchedule(
        baseId,
        '${item.category.emoji} ${item.name} expires in 2 days',
        'Plan to use it soon before it goes to waste.',
        twoDayAt9,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.expiryChannelId,
            AppConstants.expiryChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 1 day before expiry at 9am
    final oneDayDate = item.expiryDate.subtract(const Duration(days: 1));
    final oneDayAt9 = at9am(oneDayDate);
    if (oneDayAt9.isAfter(tz.TZDateTime.now(tz.local))) {
      await _plugin.zonedSchedule(
        baseId + 1,
        '${item.category.emoji} ${item.name} expires tomorrow! Use it today.',
        'Tap to see recipes you can make with it right now.',
        oneDayAt9,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.expiryChannelId,
            AppConstants.expiryChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelReminder(String itemId) async {
    final baseId = itemId.hashCode.abs() % 100000000;
    await _plugin.cancel(baseId);
    await _plugin.cancel(baseId + 1);
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Schedules a repeating Sunday 9am notification reminding the user to check
  /// their weekly waste report. Call once on first launch.
  Future<void> scheduleWeeklyReport() async {
    if (!_initialized) await init();
    final now = tz.TZDateTime.now(tz.local);
    // Find the next Sunday at 09:00
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    final daysUntilSunday = (DateTime.sunday - scheduled.weekday + 7) % 7;
    scheduled = scheduled.add(Duration(days: daysUntilSunday == 0 ? 7 : daysUntilSunday));

    await _plugin.zonedSchedule(
      777777,
      '📊 Your weekly pantry report',
      'See how much food you saved (or wasted) this week.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.expiryChannelId,
          AppConstants.expiryChannelName,
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Shows an immediate notification with real waste stats for the week.
  Future<void> showWeeklyReport({
    required double wastedValue,
    required int wastedCount,
    required int savedCount,
  }) async {
    if (!_initialized) await init();
    final String title;
    final String body;
    if (wastedCount == 0) {
      title = '🎉 Zero waste this week!';
      body = 'Amazing — you used everything before it expired.';
    } else if (wastedValue > 0) {
      title = '📊 Weekly report: \$${wastedValue.toStringAsFixed(2)} wasted';
      body = '$wastedCount item${wastedCount == 1 ? '' : 's'} wasted · $savedCount consumed. Tap to review.';
    } else {
      title = '📊 Weekly report: $wastedCount item${wastedCount == 1 ? '' : 's'} wasted';
      body = '$savedCount item${savedCount == 1 ? '' : 's'} consumed this week. Tap to review.';
    }
    await _plugin.show(
      888888,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.expiryChannelId,
          AppConstants.expiryChannelName,
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showDailySummary(int expiringCount) async {
    if (!_initialized) await init();
    await _plugin.show(
      999999,
      '🛒 PantryPal Daily Summary',
      '$expiringCount item${expiringCount == 1 ? '' : 's'} expiring soon in your pantry.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.expiryChannelId,
          AppConstants.expiryChannelName,
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
