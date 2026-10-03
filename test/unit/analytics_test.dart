import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';

import '../support/plugin_stubs.dart';

class _Fake {
  final requests = <http.Request>[];
  int status = 201;
  bool offline = false;

  MockClient get client => MockClient((req) async {
        if (offline) throw Exception('offline');
        requests.add(req);
        return http.Response('', status);
      });

  List<Map<String, dynamic>> get sent =>
      requests.expand((r) => (jsonDecode(r.body) as List).cast<Map<String, dynamic>>()).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Fake net;
  late DateTime now;
  Analytics make() => Analytics.forTest(client: net.client, clock: () => now);

  setUp(() {
    stubSharedPreferences();
    net = _Fake();
    now = DateTime(2026, 10, 1, 12);
  });

  group('what gets recorded', () {
    test('an event carries a name, anonymous id, version, platform and day index', () async {
      final a = make();
      await a.init();
      a.log('scan_completed', {'kind': 'fridge', 'items': 12});
      await Future<void>.delayed(Duration.zero);
      await a.flush();

      final e = net.sent.single;
      expect(e['name'], 'scan_completed');
      expect(e['props'], {'kind': 'fridge', 'items': 12});
      expect(e['install_id'], a.installId);
      expect(e['install_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(e['app_version'], isNotEmpty);
      expect(e['day_index'], 0);
      expect(e.keys.toSet(), {'install_id', 'name', 'props', 'app_version', 'platform', 'day_index'},
          reason: 'nothing else — no device id, IP, user or text fields');
      a.dispose();
    });

    test('the install id is stable across launches', () async {
      final a = make();
      await a.init();
      final id = a.installId;
      a.dispose();

      final b = make();
      await b.init();
      expect(b.installId, id);
      b.dispose();
    });

    test('day index counts whole days since first launch', () async {
      final a = make();
      await a.init();
      now = now.add(const Duration(days: 3, hours: 5));
      a.log('app_open');
      await Future<void>.delayed(Duration.zero);
      await a.flush();
      expect(net.sent.single['day_index'], 3);
      a.dispose();
    });

    test('enums are recorded by name', () async {
      final a = make();
      await a.init();
      a.log('x', {'kind': _Kind.fridge});
      await Future<void>.delayed(Duration.zero);
      expect(a.pending.single['props'], {'kind': 'fridge'});
      a.dispose();
    });
  });

  group('sanitize keeps properties small and non-personal', () {
    test('drops lists, maps, objects and nulls', () {
      final out = Analytics.sanitize({
        'ok': 1,
        'flag': true,
        'list': [1, 2],
        'map': {'a': 1},
        'nothing': null,
        'obj': Object(),
      });
      expect(out, {'ok': 1, 'flag': true});
    });

    test('truncates long text and rounds decimals', () {
      final out = Analytics.sanitize({'s': 'x' * 100, 'd': 3.14159});
      expect((out['s'] as String).length, 40);
      expect(out['d'], 3.14);
    });

    test('caps the number of properties', () {
      final out = Analytics.sanitize({for (var i = 0; i < 40; i++) 'k$i': i});
      expect(out.length, 12);
    });

    test('non-finite numbers are dropped', () {
      expect(Analytics.sanitize({'a': double.nan, 'b': double.infinity}).values.where((v) => v != null), isEmpty);
    });
  });

  group('consent', () {
    test('switched off: nothing is queued or sent', () async {
      final a = make();
      await a.init();
      await a.setEnabled(false);
      a.log('app_open');
      await Future<void>.delayed(Duration.zero);
      await a.flush();
      expect(a.pending, isEmpty);
      expect(net.requests, isEmpty);
      a.dispose();
    });

    test('switching off discards anything still waiting', () async {
      final a = make();
      await a.init();
      a.log('app_open');
      await Future<void>.delayed(Duration.zero);
      expect(a.pending, hasLength(1));
      await a.setEnabled(false);
      expect(a.pending, isEmpty);
      a.dispose();
    });

    test('the choice survives a restart', () async {
      final a = make();
      await a.init();
      await a.setEnabled(false);
      a.dispose();

      final b = make();
      await b.init();
      expect(b.enabled, isFalse);
      b.dispose();
    });
  });

  group('delivery', () {
    test('events are sent as one batch in a single request', () async {
      final a = make();
      await a.init();
      for (var i = 0; i < 5; i++) {
        a.log('e$i');
      }
      await Future<void>.delayed(Duration.zero);
      await a.flush();
      expect(net.requests, hasLength(1));
      expect(net.sent.map((e) => e['name']), ['e0', 'e1', 'e2', 'e3', 'e4']);
      expect(net.requests.single.url.path, '/rest/v1/app_events');
      expect(net.requests.single.headers['Prefer'], 'return=minimal');
      a.dispose();
    });

    test('a full batch is sent without waiting for the timer', () async {
      final a = make();
      await a.init();
      for (var i = 0; i < Analytics.batchSize; i++) {
        a.log('e$i');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(net.sent, hasLength(Analytics.batchSize));
      a.dispose();
    });

    test('offline: events are kept and sent later, none lost', () async {
      final a = make();
      await a.init();
      net.offline = true;
      a.log('a');
      a.log('b');
      await Future<void>.delayed(Duration.zero);
      await a.flush();
      expect(a.pending, hasLength(2));

      net.offline = false;
      await a.flush();
      expect(net.sent.map((e) => e['name']), ['a', 'b']);
      expect(a.pending, isEmpty);
      a.dispose();
    });

    test('a server error (5xx) keeps events for retry', () async {
      final a = make();
      await a.init();
      net.status = 503;
      a.log('a');
      await Future<void>.delayed(Duration.zero);
      await a.flush();
      expect(a.pending, hasLength(1));
      a.dispose();
    });

    test('a rejection (4xx) drops the batch instead of retrying forever', () async {
      final a = make();
      await a.init();
      net.status = 400;
      a.log('a');
      await Future<void>.delayed(Duration.zero);
      await a.flush();
      expect(a.pending, isEmpty);
      a.dispose();
    });

    test('unsent events survive an app restart', () async {
      final a = make();
      await a.init();
      net.offline = true;
      a.log('kept');
      await Future<void>.delayed(Duration.zero);
      a.dispose();

      final b = make();
      await b.init();
      await Future<void>.delayed(const Duration(milliseconds: 20)); // startup retry (fails: offline)
      expect(b.pending.map((e) => e['name']), ['kept']);
      net.offline = false;
      await b.flush();
      expect(net.sent.map((e) => e['name']), ['kept']);
      b.dispose();
    });

    test('the offline queue is capped so it can never grow without bound', () async {
      final a = make();
      await a.init();
      net.offline = true;
      for (var i = 0; i < Analytics.maxQueue + 50; i++) {
        a.log('e$i');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(a.pending.length, lessThanOrEqualTo(Analytics.maxQueue));
      expect(a.pending.last['name'], 'e${Analytics.maxQueue + 49}', reason: 'newest are kept');
      a.dispose();
    });

    test('an analytics failure never throws into the app', () async {
      final a = Analytics.forTest(
        client: MockClient((_) async => throw StateError('boom')),
        clock: () => now,
      );
      await a.init();
      a.log('x');
      await Future<void>.delayed(Duration.zero);
      await expectLater(a.flush(), completes);
      a.dispose();
    });
  });

  group('logOnce', () {
    test('records only the first time, even across restarts', () async {
      final a = make();
      await a.init();
      a.logOnce('first_food_added');
      a.logOnce('first_food_added');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(a.pending.where((e) => e['name'] == 'first_food_added'), hasLength(1));
      await a.flush();
      a.dispose();

      final b = make();
      await b.init();
      b.logOnce('first_food_added');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(b.pending, isEmpty);
      b.dispose();
    });
  });

  startupTests();
}

enum _Kind { fridge }

void startupTests() {
  group('startup', () {
    test('events left over from last session are sent on the next launch', () async {
      final net = _Fake();
      stubSharedPreferences();
      final a = Analytics.forTest(client: (net..offline = true).client, clock: () => DateTime(2026, 10, 1));
      await a.init();
      a.log('left_over');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      a.dispose();

      net.offline = false;
      final b = Analytics.forTest(client: net.client, clock: () => DateTime(2026, 10, 1));
      await b.init();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(net.sent.map((e) => e['name']), ['left_over']);
      b.dispose();
    });
  });
}
