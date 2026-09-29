import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:pantrypal/core/config/backend_config.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/scan/data/ai_scan_client.dart';

late String photo;
int _n = 0;

/// A tiny real JPEG; each call is different so the result cache never crosses tests.
String makePhoto({int w = 40, int h = 30}) {
  _n++;
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(_n * 7 % 255, _n * 13 % 255, 60));
  final f = File('${Directory.systemTemp.path}/scan_test_${DateTime.now().microsecondsSinceEpoch}_$_n.jpg');
  f.writeAsBytesSync(img.encodeJpg(image));
  return f.path;
}

/// Anthropic-style SSE: the reply text split into small deltas.
http.StreamedResponse sse(String text, {int chunk = 7, int status = 200}) {
  final events = <String>[
    'event: message_start\ndata: {"type":"message_start"}\n\n',
    'data: {"type":"ping"}\n\n',
  ];
  for (var i = 0; i < text.length; i += chunk) {
    final part = text.substring(i, i + chunk > text.length ? text.length : i + chunk);
    events.add('data: ${jsonEncode({
          'type': 'content_block_delta',
          'delta': {'type': 'text_delta', 'text': part},
        })}\n\n');
  }
  events.add('data: {"type":"message_stop"}\n\n');
  return http.StreamedResponse(
    Stream.fromIterable(events.map(utf8.encode)),
    status,
    headers: {'content-type': 'text/event-stream'},
  );
}

http.StreamedResponse json(Object body, {int status = 200}) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json'},
    );

const reply = '''[
  {"name":"whole milk","category":"dairy","quantity":1,"unit":"bottle","estimatedExpiryDays":7,"confidence":"high","box":[100,200,300,500]},
  {"name":"Eggs","category":"eggs","quantity":6,"unit":"item","estimatedExpiryDays":21,"confidence":"medium"},
  {"name":"Mystery jar","category":"condiments","quantity":1,"unit":"jar","estimatedExpiryDays":90,"confidence":"low","box":[600,600,700,700]}
]''';

void main() {
  setUp(() {
    AiScanClient.clearCache();
    photo = makePhoto();
  });

  group('JsonObjectStreamParser', () {
    test('emits each object only once it is complete', () {
      final p = JsonObjectStreamParser();
      expect(p.feed('[{"name":"Mi'), isEmpty);
      final first = p.feed('lk"},{"name":"Egg');
      expect(first.map((m) => m['name']), ['Milk']);
      final second = p.feed('s"}]');
      expect(second.map((m) => m['name']), ['Eggs']);
    });

    test('braces and quotes inside strings do not confuse it', () {
      final p = JsonObjectStreamParser();
      final out = p.feed(r'[{"name":"Salt } \"fine\" {"},{"name":"Rice"}]');
      expect(out.map((m) => m['name']), [r'Salt } "fine" {', 'Rice']);
    });

    test('ignores markdown fences and chatter around the array', () {
      final out = JsonObjectStreamParser().feed('Here you go:\n```json\n[{"name":"Milk"}]\n```');
      expect(out.single['name'], 'Milk');
    });

    test('a malformed object is skipped, the rest still arrive', () {
      final out = JsonObjectStreamParser().feed('[{"name":"A"},{"name":,},{"name":"C"}]');
      expect(out.map((m) => m['name']), ['A', 'C']);
    });

    test('character-by-character feeding gives the same result', () {
      final p = JsonObjectStreamParser();
      final all = <String>[];
      for (final ch in reply.split('')) {
        all.addAll(p.feed(ch).map((m) => m['name'] as String));
      }
      expect(all, ['whole milk', 'Eggs', 'Mystery jar']);
    });
  });

  group('normalizeScanItem', () {
    test('cleans name, keeps confidence, scales the box to 0-1', () {
      final m = normalizeScanItem({
        'name': ' whole   milk ',
        'category': 'dairy',
        'confidence': 'LOW',
        'box': [100, 200, 300, 500],
      }, ScanKind.fridge)!;
      expect(m['name'], 'Whole Milk');
      expect(m['confidence'], 'low');
      expect(m['box'], [0.1, 0.2, 0.3, 0.5]);
    });

    test('drops things that are not food', () {
      for (final junk in ['Container', 'shelf', 'Plastic Bag', '', 'x' * 80]) {
        expect(normalizeScanItem({'name': junk}, ScanKind.fridge), isNull, reason: junk);
      }
    });

    test('rejects implausible boxes instead of drawing them wrongly', () {
      Map<String, dynamic>? withBox(List<num> b) =>
          normalizeScanItem({'name': 'Milk', 'box': b}, ScanKind.fridge);
      expect(withBox([0, 0, 1000, 1000])!['box'], isNull, reason: 'whole-frame is not a detection');
      expect(withBox([500, 500, 510, 510])!['box'], isNull, reason: 'a speck');
      expect(withBox([300, 300, 200, 200])!['box'], isNull, reason: 'inverted');
      expect(withBox([100, 100, 400, 400])!['box'], isNotNull);
    });

    test('missing confidence counts as high, so older backends behave as before', () {
      expect(normalizeScanItem({'name': 'Milk'}, ScanKind.fridge)!['confidence'], 'high');
    });

    test('known foods get the app\'s consistent shelf life on a fridge scan', () {
      final m = normalizeScanItem({'name': 'Milk', 'category': 'dairy', 'estimatedExpiryDays': 3}, ScanKind.fridge)!;
      expect(m['estimatedExpiryDays'], 7);
      final r = normalizeScanItem({'name': 'Milk', 'estimatedExpiryDays': 3}, ScanKind.receipt)!;
      expect(r['estimatedExpiryDays'], 3, reason: 'receipts keep the model\'s estimate');
    });

    test('absurd quantities fall back to 1', () {
      expect(normalizeScanItem({'name': 'Milk', 'quantity': 400}, ScanKind.fridge)!['quantity'], 1.0);
      expect(normalizeScanItem({'name': 'Milk', 'quantity': -2}, ScanKind.fridge)!['quantity'], 1.0);
    });
  });

  group('AiScanClient (streaming backend)', () {
    test('reports growing item lists, then done', () async {
      final client = MockClient.streaming((_, __) async => sse(reply));
      final updates = await AiScanClient.scan(ScanKind.fridge, photo, client: client).toList();

      expect(updates.first.phase, ScanPhase.preparing);
      expect(updates[1].phase, ScanPhase.analyzing);
      expect(updates[1].imageSize, isNotNull);

      final counts = updates.where((u) => u.phase == ScanPhase.streaming).map((u) => u.items.length).toList();
      expect(counts, [1, 2, 3], reason: 'each item surfaces as soon as it is complete');
      expect(updates.last.phase, ScanPhase.done);
      expect(updates.last.items.map((i) => i['name']), ['Whole Milk', 'Eggs', 'Mystery Jar']);
    });

    test('items arrive before the reply has finished', () async {
      final client = MockClient.streaming((_, __) async => sse(reply, chunk: 5));
      var firstItemAt = -1, index = 0;
      final updates = <ScanUpdate>[];
      await for (final u in AiScanClient.scan(ScanKind.fridge, photo, client: client)) {
        updates.add(u);
        if (firstItemAt < 0 && u.items.isNotEmpty) firstItemAt = index;
        index++;
      }
      expect(firstItemAt, lessThan(updates.length - 2));
    });

    test('low-confidence items are flagged, not dropped', () async {
      final client = MockClient.streaming((_, __) async => sse(reply));
      final done = (await AiScanClient.scan(ScanKind.fridge, photo, client: client).toList()).last;
      final jar = done.items.firstWhere((i) => i['name'] == 'Mystery Jar');
      expect(jar['confidence'], 'low');
      expect(jar['category'], FoodCategory.condiments);
    });

    test('duplicate names merge quantities', () async {
      const dup = '[{"name":"Eggs","quantity":3},{"name":"eggs","quantity":2}]';
      final client = MockClient.streaming((_, __) async => sse(dup));
      final done = (await AiScanClient.scan(ScanKind.fridge, photo, client: client).toList()).last;
      expect(done.items.single['quantity'], 5.0);
    });

    test('a stream error event surfaces as a readable failure', () async {
      final client = MockClient.streaming((_, __) async => http.StreamedResponse(
            Stream.value(utf8.encode('data: {"type":"error","error":{"message":"Overloaded"}}\n\n')),
            200,
            headers: {'content-type': 'text/event-stream'},
          ));
      expect(
        AiScanClient.scan(ScanKind.fridge, photo, client: client).toList(),
        throwsA(isA<BackendException>().having((e) => e.message, 'message', 'Overloaded')),
      );
    });

    test('an HTTP error becomes the server\'s own message', () async {
      final client = MockClient.streaming((_, __) async => json({'error': 'Server not configured'}, status: 500));
      expect(
        AiScanClient.scan(ScanKind.receipt, photo, client: client).toList(),
        throwsA(isA<BackendException>().having((e) => e.message, 'message', 'Server not configured')),
      );
    });

    test('sends the photo as a streaming request to the right function', () async {
      late http.BaseRequest seen;
      late String body;
      final client = MockClient.streaming((req, stream) async {
        seen = req;
        body = await stream.bytesToString();
        return sse('[]');
      });
      await AiScanClient.scan(ScanKind.receipt, photo, client: client).toList();
      expect(seen.url.path, endsWith('/analyze-receipt'));
      final sent = jsonDecode(body) as Map<String, dynamic>;
      expect(sent['stream'], true);
      expect(sent['mediaType'], 'image/jpeg');
      expect((sent['image'] as String).isNotEmpty, isTrue);
    });
  });

  group('AiScanClient (older one-shot backend)', () {
    test('still works: everything arrives in one final update', () async {
      final client = MockClient.streaming((_, __) async => json({'result': reply}));
      final updates = await AiScanClient.scan(ScanKind.fridge, photo, client: client).toList();
      expect(updates.where((u) => u.phase == ScanPhase.streaming), isEmpty);
      expect(updates.last.phase, ScanPhase.done);
      expect(updates.last.items.length, 3);
    });

    test('empty answer yields a done update with no items', () async {
      final client = MockClient.streaming((_, __) async => json({'result': 'nothing here'}));
      final last = (await AiScanClient.scan(ScanKind.fridge, photo, client: client).toList()).last;
      expect(last.items, isEmpty);
    });
  });

  group('Photo preparation and cache', () {
    test('scanning the same photo twice only calls the backend once', () async {
      var calls = 0;
      final client = MockClient.streaming((_, __) async {
        calls++;
        return sse(reply);
      });
      final first = await AiScanClient.scan(ScanKind.fridge, photo, client: client).toList();
      final second = await AiScanClient.scan(ScanKind.fridge, photo, client: client).toList();

      expect(calls, 1);
      expect(second.last.fromCache, isTrue);
      expect(second.last.items.length, first.last.items.length);
      expect(second.map((u) => u.phase), contains(ScanPhase.done));
    });

    test('a cached result is a copy — editing it does not poison the cache', () async {
      final client = MockClient.streaming((_, __) async => sse(reply));
      await AiScanClient.scan(ScanKind.fridge, photo, client: client).toList();
      final a = (await AiScanClient.scan(ScanKind.fridge, photo, client: client).toList()).last;
      a.items.first['name'] = 'Tampered';
      final b = (await AiScanClient.scan(ScanKind.fridge, photo, client: client).toList()).last;
      expect(b.items.first['name'], 'Whole Milk');
    });

    test('big photos are shrunk to the kind\'s size limit before upload', () async {
      final big = makePhoto(w: 3000, h: 2000);
      late String body;
      final client = MockClient.streaming((req, stream) async {
        body = await stream.bytesToString();
        return sse('[]');
      });
      final updates = await AiScanClient.scan(ScanKind.fridge, big, client: client).toList();
      final size = updates.firstWhere((u) => u.imageSize != null).imageSize!;
      expect(size.width, ScanKind.fridge.maxSide.toDouble());
      expect(size.height, closeTo(ScanKind.fridge.maxSide * 2 / 3, 2), reason: 'aspect ratio kept');
      final decoded = img.decodeJpg(base64Decode((jsonDecode(body) as Map)['image'] as String))!;
      expect(decoded.width, ScanKind.fridge.maxSide);
    });

    test('small photos are not enlarged', () async {
      final updates = await AiScanClient.scan(ScanKind.fridge, photo,
          client: MockClient.streaming((_, __) async => sse('[]'))).toList();
      expect(updates.firstWhere((u) => u.imageSize != null).imageSize!.width, 40);
    });
  });
}
