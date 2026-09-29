import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Set this to handle a notification tap — opens Cook Tonight for the expiring items.
  static void Function(String? itemName)? onNotificationTap;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    // Permission is requested later, at a moment the user understands
    // (see requestPermission) — never as a bare system dialog at launch.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
      onDidReceiveNotificationResponse: (r) => onNotificationTap?.call(r.payload),
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
    _initialized = true;
  }

  /// Shows the system permission dialog. Call right after telling the user
  /// what they will get. Returns whether notifications are allowed.
  Future<bool> requestPermission() async {
    if (!_initialized) await init();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final android = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return ios ?? android ?? false;
  }

  // ── Daily "use it up" digest ──────────────────────────────────────────────
  //
  // One quiet evening notification on the days something needs using — not two
  // per item. A 30-item receipt used to schedule 60 alerts and blow through
  // iOS's 64-pending limit; this never schedules more than [_digestDays].

  static const _digestBaseId = 500000;
  static const _digestDays = 14;
  static const prefReminderEnabled = 'reminder_enabled';
  static const prefReminderHour = 'reminder_hour';
  static const prefReminderMinute = 'reminder_minute';

  Future<({bool enabled, int hour, int minute})> reminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      enabled: prefs.getBool(prefReminderEnabled) ?? true,
      hour: prefs.getInt(prefReminderHour) ?? 18,
      minute: prefs.getInt(prefReminderMinute) ?? 0,
    );
  }

  Future<void> saveReminderSettings({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefReminderEnabled, enabled);
    await prefs.setInt(prefReminderHour, hour);
    await prefs.setInt(prefReminderMinute, minute);
  }

  /// Rebuilds the next two weeks of digests from what is in the pantry now.
  /// Safe to call after every change; failures never reach the user.
  Future<void> refreshDigest(List<PantryItem> items) async {
    try {
      if (!_initialized) await init();
      for (var i = 0; i < _digestDays; i++) {
        await _plugin.cancel(_digestBaseId + i);
      }
      final settings = await reminderSettings();
      if (!settings.enabled) return;

      final active = items.where((i) => i.isActive).toList();
      if (active.isEmpty) return;

      final now = tz.TZDateTime.now(tz.local);
      for (var d = 0; d < _digestDays; d++) {
        final day = tz.TZDateTime(tz.local, now.year, now.month, now.day + d,
            settings.hour, settings.minute);
        if (!day.isAfter(now)) continue;

        final content = digestContent(active, DateTime(day.year, day.month, day.day));
        if (content == null) continue;

        await _plugin.zonedSchedule(
          _digestBaseId + d,
          content.title,
          content.body,
          day,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              AppConstants.expiryChannelId,
              AppConstants.expiryChannelName,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'digest',
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] refreshDigest failed: $e');
    }
  }

  /// What the digest for [day] should say, or null when nothing needs using
  /// that day. Items count if they expire within 2 days of [day]; on the
  /// first day anything already past its date is included too.
  @visibleForTesting
  static ({String title, String body})? digestContent(
    List<PantryItem> items,
    DateTime day,
  ) {
    final dayUtc = DateTime.utc(day.year, day.month, day.day);
    final today = DateTime.now();
    final isFirstDay = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;

    final due = <(PantryItem, int)>[];
    for (final item in items) {
      final e = item.expiryDate;
      final left = DateTime.utc(e.year, e.month, e.day).difference(dayUtc).inDays;
      if (left >= 0 && left <= 2 || (isFirstDay && left < 0)) due.add((item, left));
    }
    if (due.isEmpty) return null;
    due.sort((a, b) => a.$2.compareTo(b.$2));

    String when(int left) => left < 0
        ? 'expired'
        : left == 0
            ? 'today'
            : left == 1
                ? 'tomorrow'
                : 'in $left days';

    final shown = due.take(3).map((d) => '${d.$1.name} (${when(d.$2)})').join(', ');
    final extra = due.length > 3 ? ' +${due.length - 3} more' : '';
    final title = due.length == 1
        ? 'Use up ${due.first.$1.name} ${when(due.first.$2)}'
        : '${due.length} things to use up soon';
    return (
      title: title,
      body: '$shown$extra. Tap for a dinner idea that uses them.',
    );
  }

  /// One-off clean-up of the old per-item reminders (v1) so they stop firing.
  Future<void> migrateLegacyReminders() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('digest_v2') ?? false) return;
    try {
      if (!_initialized) await init();
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] legacy cleanup failed: $e');
    }
    await prefs.setBool('weekly_report_scheduled', false);
    await prefs.setBool('digest_v2', true);
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
