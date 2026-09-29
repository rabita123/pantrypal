// Method-channel stubs for the native plugins the domain layer touches.
//
// PantryRepository schedules notifications and PantryBloc pushes home-widget
// data; neither has a native side in a Dart test process. These stubs let the
// real production code paths run instead of being mocked out wholesale.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void _stub(String channel, [Object? Function(MethodCall call)? handler]) {
  _messenger.setMockMethodCallHandler(
    MethodChannel(channel),
    (call) async => handler?.call(call),
  );
}

/// flutter_local_notifications + flutter_timezone.
void stubNotificationPlugin() {
  _stub('dexterous.com/flutter/local_notifications', (call) {
    switch (call.method) {
      case 'initialize':
      case 'requestPermissions':
        return true;
      case 'pendingNotificationRequests':
      case 'getActiveNotifications':
        return <Object?>[];
      default:
        return null;
    }
  });
  _stub('flutter_timezone', (call) => 'UTC');
}

/// home_widget — the iOS widget bridge.
void stubHomeWidgetPlugin() {
  _stub('home_widget', (call) => true);
}

/// shared_preferences — uses the plugin's own in-memory test backend, which
/// correctly handles the prefix and type encoding the real implementation uses.
void stubSharedPreferences([Map<String, Object> initial = const {}]) {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(initial));
}
