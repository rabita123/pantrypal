import 'dart:async';
import 'dart:io';

/// Single source of truth for the hosted AI backend.
///
/// The three AI features — Smart Recipe, Fridge Scan and Receipt Scan — all
/// call Supabase Edge Functions on this project. Keeping the URL and key here
/// means pointing the app at a different project is a one-line change rather
/// than three files drifting out of sync.
class BackendConfig {
  const BackendConfig._();

  static const supabaseUrl = 'https://hwkaxobdmyiyodtgrpio.supabase.co';

  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3a2F4b2JkbXlpeW9kdGdycGlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyMjEyNjcsImV4cCI6MjA5NTc5NzI2N30.naKIQOSgMjP_-yM5fiNpiwpkSB2SuNHha9uVSTJF4Ug';

  /// Full URL of an Edge Function by name.
  static Uri function(String name) =>
      Uri.parse('$supabaseUrl/functions/v1/$name');

  static Map<String, String> get headers => {
        'Authorization': 'Bearer $supabaseAnonKey',
        'apikey': supabaseAnonKey,
        'Content-Type': 'application/json',
      };
}

/// A failure the user is allowed to read.
///
/// Raw `SocketException` and `ClientException` text names the internal host and
/// an errno, which tells the user nothing they can act on. Every AI call wraps
/// its failures in one of these instead.
class BackendException implements Exception {
  final String message;
  const BackendException(this.message);

  @override
  String toString() => message;

  /// Maps a low-level failure onto plain language.
  static BackendException from(Object error) {
    if (error is BackendException) return error;
    if (error is TimeoutException) {
      return const BackendException(
          'That took too long. Check your connection and try again.');
    }
    if (error is SocketException || _looksLikeNetworkFailure(error)) {
      return const BackendException(
          "Can't reach the recipe service. Check your internet connection — "
          'if you are online, the service may be temporarily unavailable.');
    }
    return const BackendException(
        'Something went wrong on our side. Please try again in a moment.');
  }

  // http throws ClientException for DNS and connection failures; matching on
  // the type directly would pull package:http into every caller.
  static bool _looksLikeNetworkFailure(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('connection closed') ||
        text.contains('network is unreachable');
  }
}
