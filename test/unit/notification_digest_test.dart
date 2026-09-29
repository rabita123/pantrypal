import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/shared/services/notification_service.dart';

import '../support/fixtures.dart';
import '../support/plugin_stubs.dart';

void main() {
  final today = DateTime.now();
  final day = DateTime(today.year, today.month, today.day);

  group('digestContent', () {
    test('is null when nothing needs using', () {
      expect(NotificationService.digestContent([item(daysFromNow: 20)], day), isNull);
      expect(NotificationService.digestContent([], day), isNull);
    });

    test('names a single item and when it expires', () {
      final c = NotificationService.digestContent([item(name: 'Spinach', daysFromNow: 1)], day)!;
      expect(c.title, 'Use up Spinach tomorrow');
      expect(c.body, contains('Spinach (tomorrow)'));
    });

    test('groups several items into one message, most urgent first', () {
      final c = NotificationService.digestContent([
        item(name: 'Yogurt', daysFromNow: 2),
        item(name: 'Chicken', daysFromNow: 0),
        item(name: 'Milk', daysFromNow: 1),
      ], day)!;
      expect(c.title, '3 things to use up soon');
      expect(c.body.indexOf('Chicken'), lessThan(c.body.indexOf('Milk')));
      expect(c.body.indexOf('Milk'), lessThan(c.body.indexOf('Yogurt')));
    });

    test('summarises overflow instead of listing everything', () {
      final many = [for (var i = 0; i < 6; i++) item(name: 'Item$i', daysFromNow: 1)];
      final c = NotificationService.digestContent(many, day)!;
      expect(c.title, '6 things to use up soon');
      expect(c.body, contains('+3 more'));
    });

    test('a later day only counts food expiring within two days of it', () {
      final later = day.add(const Duration(days: 5));
      final items = [item(name: 'Soon', daysFromNow: 6), item(name: 'Far', daysFromNow: 20)];
      final c = NotificationService.digestContent(items, later)!;
      expect(c.body, contains('Soon'));
      expect(c.body, isNot(contains('Far')));
    });

    test('already-expired food is only raised on the first day', () {
      final expired = item(name: 'Old', daysFromNow: -2);
      expect(NotificationService.digestContent([expired], day)!.body, contains('Old (expired)'));
      expect(NotificationService.digestContent([expired], day.add(const Duration(days: 3))), isNull);
    });
  });

  schedulingTests();
}

// A big shop must never turn into a wall of notifications.
void schedulingTests() {
  group('refreshDigest scheduling', () {
    final scheduled = <MethodCall>[];

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      stubSharedPreferences();
      stubHomeWidgetPlugin();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async {
          if (call.method == 'zonedSchedule') scheduled.add(call);
          if (call.method == 'initialize') return true;
          if (call.method == 'pendingNotificationRequests') return <Object?>[];
          return null;
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        (call) async => 'UTC',
      );
    });

    setUp(() {
      scheduled.clear();
      stubSharedPreferences();
    });

    test('30 expiring items schedule at most one notification per day', () async {
      final items = [for (var i = 0; i < 30; i++) item(name: 'Item$i', daysFromNow: 1 + i % 3)];
      await NotificationService.instance.refreshDigest(items);
      expect(scheduled.length, lessThanOrEqualTo(14));
      expect(scheduled, isNotEmpty);
    });

    test('nothing is scheduled when reminders are switched off', () async {
      stubSharedPreferences({'reminder_enabled': false});
      await NotificationService.instance.refreshDigest([item(daysFromNow: 1)]);
      expect(scheduled, isEmpty);
    });

    test('nothing is scheduled for an empty pantry', () async {
      await NotificationService.instance.refreshDigest([]);
      expect(scheduled, isEmpty);
    });
  });
}
