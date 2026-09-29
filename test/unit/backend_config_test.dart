// The three AI services share one backend definition and one error vocabulary.
// These tests pin both — the URL/key must not drift between features again,
// and users must never be shown a raw socket exception.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/config/backend_config.dart';

void main() {
  group('Endpoint construction', () {
    test('builds each Edge Function URL from one base', () {
      expect(BackendConfig.function('generate-recipe').toString(),
          '${BackendConfig.supabaseUrl}/functions/v1/generate-recipe');
      expect(BackendConfig.function('analyze-fridge').toString(),
          '${BackendConfig.supabaseUrl}/functions/v1/analyze-fridge');
      expect(BackendConfig.function('analyze-receipt').toString(),
          '${BackendConfig.supabaseUrl}/functions/v1/analyze-receipt');
    });

    test('sends both auth headers Supabase requires', () {
      final h = BackendConfig.headers;
      expect(h['Authorization'], 'Bearer ${BackendConfig.supabaseAnonKey}');
      expect(h['apikey'], BackendConfig.supabaseAnonKey);
      expect(h['Content-Type'], 'application/json');
    });

    test('the configured URL is a well-formed https origin', () {
      final uri = Uri.parse(BackendConfig.supabaseUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
      expect(uri.path, isEmpty, reason: 'base URL must not carry a path');
    });
  });

  group('User-facing errors', () {
    test('a DNS failure reads as a connection problem, not an errno', () {
      final e = BackendException.from(const SocketException(
          "Failed host lookup: 'example.supabase.co' "
          '(OS Error: nodename nor servname provided, errno = 8)'));

      expect(e.message, contains('connection'));
      expect(e.message, isNot(contains('errno')));
      expect(e.message, isNot(contains('OS Error')));
      expect(e.message, isNot(contains('supabase')));
    });

    test("http's ClientException is recognised as a network failure", () {
      // Thrown by package:http for DNS and connection errors — matched by
      // text so callers need not import http just to classify a failure.
      final e = BackendException.from(
          Exception('ClientException with SocketException: Failed host lookup'));
      expect(e.message, contains('connection'));
    });

    test('a timeout says so plainly', () {
      final e = BackendException.from(TimeoutException('x'));
      expect(e.message.toLowerCase(), contains('too long'));
    });

    test('an unknown failure gets a safe generic message', () {
      final e = BackendException.from(StateError('null pointer in parser'));
      expect(e.message, isNot(contains('null pointer')));
      expect(e.message, isNotEmpty);
    });

    test('an already-mapped message is passed through untouched', () {
      const original = BackendException('Daily limit reached.');
      expect(BackendException.from(original).message, 'Daily limit reached.');
    });

    test('no mapped message leaks internals to the user', () {
      final samples = <Object>[
        const SocketException('Connection refused'),
        TimeoutException('x'),
        StateError('boom'),
        Exception('ClientException with SocketException'),
      ];
      for (final s in samples) {
        final m = BackendException.from(s).message.toLowerCase();
        expect(m, isNot(contains('exception')));
        expect(m, isNot(contains('errno')));
        expect(m, isNot(contains('http')));
        expect(m.endsWith('.'), isTrue, reason: 'should read as a sentence: $m');
      }
    });
  });
}
