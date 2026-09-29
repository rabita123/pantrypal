// Contract check for the hosted AI backend the app depends on.
//
// The three AI features (Smart Recipe, Fridge Scan, Receipt Scan) all POST to
// Supabase Edge Functions. These tests confirm the configured host is reachable
// and the functions respond, which no amount of local mocking can establish.
//
// Tagged `network` so `--exclude-tags network` gives a fully offline run.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pantrypal/core/config/backend_config.dart';

const _supabaseUrl = BackendConfig.supabaseUrl;
const _anonKey = BackendConfig.supabaseAnonKey;

Uri _fn(String name) => BackendConfig.function(name);

Map<String, String> get _headers => BackendConfig.headers;

void main() {
  group('Backend host', () {
    test('the Supabase project host resolves in DNS', () async {
      final host = Uri.parse(_supabaseUrl).host;
      final addresses = await InternetAddress.lookup(host);
      expect(addresses, isNotEmpty,
          reason: '$host must resolve for any AI feature to work');
    }, tags: 'network');
  });

  group('Edge functions', () {
    test('generate-recipe accepts a pantry payload', () async {
      final res = await http
          .post(_fn('generate-recipe'),
              headers: _headers,
              body: '{"items":[{"name":"Milk","category":"Dairy","daysLeft":2}]}')
          .timeout(const Duration(seconds: 40));
      expect(res.statusCode, 200, reason: 'body: ${res.body}');
    }, tags: 'network');

    test('analyze-fridge is deployed', () async {
      final res = await http
          .post(_fn('analyze-fridge'), headers: _headers, body: '{}')
          .timeout(const Duration(seconds: 40));
      expect(res.statusCode, isNot(404),
          reason: 'function must be deployed; body: ${res.body}');
    }, tags: 'network');

    test('analyze-receipt is deployed', () async {
      final res = await http
          .post(_fn('analyze-receipt'), headers: _headers, body: '{}')
          .timeout(const Duration(seconds: 45));
      expect(res.statusCode, isNot(404),
          reason: 'function must be deployed; body: ${res.body}');
    }, tags: 'network');
  });

  group('Client-side configuration', () {
    test('the anon key is not expired', () {
      // JWT payload is the middle segment; `exp` is a unix timestamp.
      final parts = _anonKey.split('.');
      expect(parts.length, 3, reason: 'anon key must be a well-formed JWT');
      final payload = String.fromCharCodes(
        base64UrlDecodePadded(parts[1]),
      );
      final expMatch = RegExp(r'"exp":(\d+)').firstMatch(payload);
      expect(expMatch, isNotNull);
      final exp = DateTime.fromMillisecondsSinceEpoch(
          int.parse(expMatch!.group(1)!) * 1000);
      expect(exp.isAfter(DateTime.now()), isTrue,
          reason: 'anon key expired on $exp');
    });
  });
}

List<int> base64UrlDecodePadded(String s) {
  final pad = s.length % 4;
  return Uri.parse('data:;base64,${s.replaceAll('-', '+').replaceAll('_', '/')}'
          '${pad == 0 ? '' : '=' * (4 - pad)}')
      .data!
      .contentAsBytes();
}
