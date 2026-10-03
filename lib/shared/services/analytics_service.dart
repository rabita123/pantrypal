import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:pantrypal/core/config/backend_config.dart';
import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Anonymous product funnel — so "why don't people subscribe?" is answered by
/// data, not guesses.
///
/// What it records: an event name (`scan_completed`), a few non-personal
/// properties (`kind`, `items`), the app version, the platform, and how many
/// days since this install first ran. Everything hangs off a random id created
/// on first launch.
///
/// What it never records: name, email, account, device or advertising id, IP,
/// photos, or what food you have. There is no cross-app tracking, so no
/// App Tracking Transparency prompt is needed. Users can switch it off in
/// Settings.
class Analytics {
  Analytics._({http.Client? client, DateTime Function()? clock})
      : _client = client,
        _clock = clock ?? DateTime.now;

  static Analytics instance = Analytics._();

  /// Test seam: a fresh instance with a fake HTTP client / clock.
  @visibleForTesting
  static Analytics forTest({http.Client? client, DateTime Function()? clock}) =>
      Analytics._(client: client, clock: clock);

  /// Fire-and-forget: `Analytics.track('paywall_shown', {'reason': 'scanLimit'})`.
  static void track(String name, [Map<String, Object?> props = const {}]) =>
      instance.log(name, props);

  static const prefEnabled = 'analytics_enabled';
  static const _prefInstallId = 'analytics_install_id';
  static const _prefFirstSeen = 'analytics_first_seen';
  static const _prefQueue = 'analytics_queue';
  static const _prefOnce = 'analytics_once';

  static const maxQueue = 200;
  static const batchSize = 20;

  final http.Client? _client;
  final DateTime Function() _clock;

  final List<Map<String, Object?>> _queue = [];
  bool _ready = false;
  bool _enabled = true;
  bool _flushing = false;
  String _installId = '';
  int _firstSeenMs = 0;
  Set<String> _once = {};
  _Lifecycle? _observer;

  bool get enabled => _enabled;

  /// Loads (or creates) the anonymous id and any events not yet sent.
  Future<void> init() async {
    if (_ready) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(prefEnabled) ?? true;
    _installId = prefs.getString(_prefInstallId) ?? const Uuid().v4();
    await prefs.setString(_prefInstallId, _installId);
    _firstSeenMs = prefs.getInt(_prefFirstSeen) ?? _clock().millisecondsSinceEpoch;
    await prefs.setInt(_prefFirstSeen, _firstSeenMs);
    _once = (prefs.getStringList(_prefOnce) ?? const []).toSet();

    for (final raw in prefs.getStringList(_prefQueue) ?? const <String>[]) {
      try {
        _queue.add(Map<String, Object?>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }
    _ready = true;

    if (_observer == null) {
      try {
        _observer = _Lifecycle(onBackground: flush);
        WidgetsBinding.instance.addObserver(_observer!);
      } catch (_) {
        // No binding (plain unit test) — batch-size flush still works.
      }
    }
    // Send anything left over from an earlier session (e.g. sent offline).
    unawaited(flush());
  }

  /// Turning it off also discards anything waiting to be sent.
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefEnabled, value);
    _enabled = value;
    if (!value) {
      _queue.clear();
      await prefs.remove(_prefQueue);
    }
  }

  void log(String name, [Map<String, Object?> props = const {}]) {
    unawaited(_log(name, props));
  }

  /// Logs [name] only the first time ever on this install (`first_food_added`).
  void logOnce(String name, [Map<String, Object?> props = const {}]) {
    unawaited(_logOnce(name, props));
  }

  Future<void> _logOnce(String name, Map<String, Object?> props) async {
    if (!_ready) await init();
    if (!_enabled || _once.contains(name)) return;
    _once.add(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefOnce, _once.toList());
    await _log(name, props);
  }

  Future<void> _log(String name, Map<String, Object?> props) async {
    try {
      if (!_ready) await init();
      if (!_enabled) return;
      final day = _clock()
          .difference(DateTime.fromMillisecondsSinceEpoch(_firstSeenMs))
          .inDays;
      _queue.add({
        'install_id': _installId,
        'name': name.length > 48 ? name.substring(0, 48) : name,
        'props': sanitize(props),
        'app_version': AppConstants.appVersion,
        'platform': _platform,
        'day_index': day < 0 ? 0 : day,
      });
      while (_queue.length > maxQueue) {
        _queue.removeAt(0);
      }
      await _persist();
      if (_queue.length >= batchSize) unawaited(flush());
    } catch (e) {
      debugPrint('[Analytics] log failed: $e');
    }
  }

  /// Sends what is waiting. On any failure the events stay queued for next
  /// time — analytics must never affect the app.
  Future<void> flush() async {
    if (!_ready || !_enabled || _flushing || _queue.isEmpty) return;
    _flushing = true;
    final batch = List<Map<String, Object?>>.from(_queue.take(100));
    final owns = _client == null;
    final client = _client ?? http.Client();
    try {
      final res = await client
          .post(
            Uri.parse('${BackendConfig.supabaseUrl}/rest/v1/app_events'),
            headers: {...BackendConfig.headers, 'Prefer': 'return=minimal'},
            body: jsonEncode(batch),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _queue.removeRange(0, batch.length);
        await _persist();
      } else if (res.statusCode >= 400 && res.statusCode < 500) {
        // The server will never accept these; drop them rather than retry forever.
        _queue.removeRange(0, batch.length);
        await _persist();
      }
    } catch (_) {
      // Offline or slow — try again later.
    } finally {
      _flushing = false;
      if (owns) client.close();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefQueue, _queue.map(jsonEncode).toList());
  }

  /// Keeps only small, flat, primitive values — no free text that could carry
  /// something personal, and never more than the database accepts.
  @visibleForTesting
  static Map<String, Object?> sanitize(Map<String, Object?> props) {
    final out = <String, Object?>{};
    for (final e in props.entries.take(12)) {
      final v = e.value;
      final key = e.key.length > 32 ? e.key.substring(0, 32) : e.key;
      if (v == null) continue;
      if (v is bool || v is int) {
        out[key] = v;
      } else if (v is double) {
        out[key] = v.isFinite ? double.parse(v.toStringAsFixed(2)) : null;
      } else if (v is String) {
        out[key] = v.length > 40 ? v.substring(0, 40) : v;
      } else if (v is Enum) {
        out[key] = v.name;
      }
      // Lists, maps and objects are dropped on purpose.
    }
    return out;
  }

  String get _platform {
    try {
      return Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : Platform.operatingSystem);
    } catch (_) {
      return 'unknown';
    }
  }

  @visibleForTesting
  List<Map<String, Object?>> get pending => List.unmodifiable(_queue);

  @visibleForTesting
  String get installId => _installId;

  @visibleForTesting
  void dispose() {
    if (_observer != null) {
      try {
        WidgetsBinding.instance.removeObserver(_observer!);
      } catch (_) {}
    }
  }
}

class _Lifecycle with WidgetsBindingObserver {
  final VoidCallback onBackground;
  _Lifecycle({required this.onBackground});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      onBackground();
    }
  }
}
