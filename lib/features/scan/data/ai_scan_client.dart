import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pantrypal/core/config/backend_config.dart';
import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/core/constants/starter_foods.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

/// What is being scanned — picks the endpoint and the photo size.
enum ScanKind {
  fridge('analyze-fridge', 1152),
  receipt('analyze-receipt', 1600);

  final String function;

  /// Longest photo edge sent to the AI. Fridges are read by shape and colour,
  /// receipts by small print, so receipts keep more resolution.
  final int maxSide;
  const ScanKind(this.function, this.maxSide);
}

enum ScanPhase { preparing, analyzing, streaming, done }

/// A progress report. [items] is always the FULL list found so far, so a
/// listener can simply replace what it shows.
class ScanUpdate {
  final ScanPhase phase;
  final List<Map<String, dynamic>> items;

  /// Pixel size of the photo that was analysed (for placing detection boxes).
  final Size? imageSize;
  final bool fromCache;

  const ScanUpdate(this.phase, {this.items = const [], this.imageSize, this.fromCache = false});
}

/// How sure the AI is about an item. Low-confidence items are never added
/// without the user confirming them.
enum ScanConfidence {
  high,
  medium,
  low;

  static ScanConfidence parse(Object? v) => switch ((v as String?)?.toLowerCase()) {
        'low' => ScanConfidence.low,
        'medium' => ScanConfidence.medium,
        _ => ScanConfidence.high,
      };
}

/// Runs a scan end to end and reports real progress as it happens:
///
///  1. Prepares the photo off the UI thread (rotation fixed, sensibly sized).
///  2. Streams the AI's answer and surfaces each item the moment it is
///     complete, instead of waiting for the whole reply.
///  3. Cleans the results (duplicates, junk, shelf life) as they arrive.
///
/// Works with the streaming backend and the older one-shot backend alike — the
/// latter just delivers everything in a single update.
class AiScanClient {
  AiScanClient._();

  static final _cache = <String, List<Map<String, dynamic>>>{};
  static const _cacheLimit = 6;

  @visibleForTesting
  static void clearCache() => _cache.clear();

  static Stream<ScanUpdate> scan(
    ScanKind kind,
    String imagePath, {
    http.Client? client,
  }) async* {
    yield const ScanUpdate(ScanPhase.preparing);

    final prepared = await compute(_prepareImage, _PrepArgs(imagePath, kind.maxSide));
    final size = prepared.width > 0 ? Size(prepared.width.toDouble(), prepared.height.toDouble()) : null;

    // Same photo scanned again (rescan, back-and-forth): reuse, don't re-bill.
    final cacheKey = '${kind.name}:${prepared.key}';
    final cached = _cache[cacheKey];
    if (cached != null) {
      yield ScanUpdate(ScanPhase.done,
          items: cached.map((m) => Map<String, dynamic>.from(m)).toList(), imageSize: size, fromCache: true);
      return;
    }

    yield ScanUpdate(ScanPhase.analyzing, imageSize: size);

    final http_ = client ?? http.Client();
    final collector = _ItemCollector(kind);
    final parser = JsonObjectStreamParser();

    try {
      final request = http.Request('POST', BackendConfig.function(kind.function))
        ..headers.addAll(BackendConfig.headers)
        ..headers['Accept'] = 'text/event-stream, application/json'
        ..body = jsonEncode({'image': prepared.base64, 'mediaType': 'image/jpeg', 'stream': true});

      final http.StreamedResponse response;
      try {
        // The one-shot backend only answers when the AI has finished, so the
        // first byte can legitimately take a while there.
        response = await http_.send(request).timeout(const Duration(seconds: 45));
      } catch (e) {
        throw BackendException.from(e);
      }

      final contentType = response.headers['content-type'] ?? '';

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw BackendException(_errorText(body) ??
            'The scan service is unavailable right now (${response.statusCode}). Please try again shortly.');
      }

      if (contentType.contains('text/event-stream')) {
        var sawItem = false;
        final lines = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(const Duration(seconds: 25), onTimeout: (sink) {
          sink.addError(TimeoutException('scan stalled'));
          sink.close();
        });

        try {
          await for (final line in lines) {
            if (!line.startsWith('data:')) continue;
            final payload = line.substring(5).trim();
            if (payload.isEmpty || payload == '[DONE]') continue;

            final Map<String, dynamic> event;
            try {
              event = jsonDecode(payload) as Map<String, dynamic>;
            } catch (_) {
              continue;
            }
            final type = event['type'];
            if (type == 'error') {
              final msg = (event['error'] as Map?)?['message'] as String?;
              throw BackendException(msg ?? 'The scan was interrupted. Please try again.');
            }
            if (type != 'content_block_delta') continue;
            final text = (event['delta'] as Map?)?['text'] as String?;
            if (text == null) continue;

            final completed = parser.feed(text);
            if (completed.isEmpty) continue;
            var changed = false;
            for (final raw in completed) {
              changed = collector.add(raw) || changed;
            }
            if (changed) {
              sawItem = true;
              yield ScanUpdate(ScanPhase.streaming, items: collector.snapshot(), imageSize: size);
            }
          }
        } on TimeoutException catch (e) {
          if (!sawItem) throw BackendException.from(e);
          // Partial results are still useful — fall through and finish.
        }
      } else {
        // Older one-shot backend: the whole answer arrives at once.
        final body = await response.stream.bytesToString();
        final err = _errorText(body);
        if (err != null) throw BackendException(err);
        final data = jsonDecode(body) as Map<String, dynamic>;
        final text = data['result'] as String? ?? '';
        for (final raw in JsonObjectStreamParser().feed(text)) {
          collector.add(raw);
        }
      }

      final items = collector.snapshot();
      if (items.isNotEmpty) {
        _cache[cacheKey] = items.map((m) => Map<String, dynamic>.from(m)).toList();
        while (_cache.length > _cacheLimit) {
          _cache.remove(_cache.keys.first);
        }
      }
      yield ScanUpdate(ScanPhase.done, items: items, imageSize: size);
    } finally {
      if (client == null) http_.close();
    }
  }

  static String? _errorText(String body) {
    try {
      final j = jsonDecode(body);
      final e = (j is Map ? j['error'] : null);
      if (e is String && e.isNotEmpty) return e;
    } catch (_) {}
    return null;
  }
}

// ── Result cleaning ───────────────────────────────────────────────────────────

/// Turns raw AI objects into clean pantry-ready maps, merging duplicates and
/// dropping anything that is plainly not food.
class _ItemCollector {
  final ScanKind kind;
  _ItemCollector(this.kind);

  final _byName = <String, Map<String, dynamic>>{};
  int _seq = 0;

  /// Returns true when the visible list changed.
  bool add(Map<String, dynamic> raw) {
    final item = normalizeScanItem(raw, kind);
    if (item == null) return false;
    final key = (item['name'] as String).toLowerCase();
    final existing = _byName[key];
    if (existing != null) {
      // Same thing seen twice (two lines on a receipt, two on a shelf).
      existing['quantity'] = (existing['quantity'] as double) + (item['quantity'] as double);
      final ep = existing['price'] as double?;
      final ip = item['price'] as double?;
      if (ip != null) existing['price'] = (ep ?? 0) + ip;
      return true;
    }
    item['id'] = 'scan-${_seq++}';
    _byName[key] = item;
    return true;
  }

  List<Map<String, dynamic>> snapshot() =>
      _byName.values.map((m) => Map<String, dynamic>.from(m)).toList();
}

const _notFood = {
  'container', 'shelf', 'drawer', 'fridge', 'refrigerator', 'bag', 'plastic bag',
  'bottle', 'jar', 'can', 'box', 'package', 'packaging', 'item', 'items', 'food',
  'unknown', 'unidentified', 'tupperware', 'bowl', 'plate', 'light', 'door',
};

/// Cleans one raw item; null when it should be dropped.
@visibleForTesting
Map<String, dynamic>? normalizeScanItem(Map<String, dynamic> raw, ScanKind kind) {
  final rawName = (raw['name'] as String?)?.trim() ?? '';
  if (rawName.isEmpty || rawName.length > 60) return null;
  if (_notFood.contains(rawName.toLowerCase())) return null;

  final name = rawName
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  final categoryStr = (raw['category'] as String? ?? 'other').toLowerCase();
  var category = FoodCategory.fromString(categoryStr);
  final starter = starterFoodFor(name);

  var qty = (raw['quantity'] as num?)?.toDouble() ?? 1.0;
  if (qty <= 0 || qty > 99) qty = 1.0;

  // Known staples get the app's own consistent shelf life and category, so the
  // same milk never expires in 5 days on one scan and 9 on the next.
  int shelf = (raw['estimatedExpiryDays'] as num?)?.toInt() ??
      AppConstants.defaultShelfLife[categoryStr] ??
      14;
  if (starter != null && kind == ScanKind.fridge) {
    shelf = starter.shelfDays;
    category = starter.category;
  }
  shelf = shelf.clamp(1, 730);

  return <String, dynamic>{
    'name': name,
    'category': category,
    'quantity': qty,
    'unit': (raw['unit'] as String?) ?? 'item',
    'price': (raw['price'] as num?)?.toDouble(),
    'estimatedExpiryDays': shelf,
    'confidence': ScanConfidence.parse(raw['confidence']).name,
    'box': _parseBox(raw['box']),
  };
}

/// Accepts [x1,y1,x2,y2] on a 0–1000 scale and returns [l,t,r,b] as 0–1
/// fractions, or null when the box is missing or implausible. Detection boxes
/// are decoration: a bad one is dropped rather than drawn in the wrong place.
List<double>? _parseBox(Object? v) {
  if (v is! List || v.length != 4 || v.any((e) => e is! num)) return null;
  final b = v.map((e) => (e as num).toDouble() / 1000).toList();
  final l = b[0].clamp(0.0, 1.0), t = b[1].clamp(0.0, 1.0);
  final r = b[2].clamp(0.0, 1.0), bt = b[3].clamp(0.0, 1.0);
  final w = r - l, h = bt - t;
  if (w < 0.03 || h < 0.03) return null; // too small to mean anything
  if (w * h > 0.55) return null; // "the whole fridge" is not a detection
  return [l, t, r, bt];
}

// ── Incremental JSON ──────────────────────────────────────────────────────────

/// Pulls each COMPLETE `{...}` object out of a JSON array that is still being
/// typed, so items can appear one by one while the AI is still writing.
class JsonObjectStreamParser {
  String _text = '';
  int _pos = 0;
  int _depth = 0;
  int _start = -1;
  bool _inString = false;
  bool _escaped = false;

  /// Feed the next chunk; returns objects completed by it.
  List<Map<String, dynamic>> feed(String chunk) {
    _text += chunk;
    final out = <Map<String, dynamic>>[];
    for (; _pos < _text.length; _pos++) {
      final c = _text[_pos];
      if (_inString) {
        if (_escaped) {
          _escaped = false;
        } else if (c == r'\') {
          _escaped = true;
        } else if (c == '"') {
          _inString = false;
        }
        continue;
      }
      if (c == '"') {
        if (_depth > 0) _inString = true;
      } else if (c == '{') {
        if (_depth == 0) _start = _pos;
        _depth++;
      } else if (c == '}' && _depth > 0) {
        _depth--;
        if (_depth == 0 && _start >= 0) {
          try {
            final decoded = jsonDecode(_text.substring(_start, _pos + 1));
            if (decoded is Map<String, dynamic>) out.add(decoded);
          } catch (_) {
            // A malformed object is skipped; the rest of the array still counts.
          }
          _start = -1;
        }
      }
    }
    return out;
  }
}

// ── Photo preparation (runs in a background isolate) ─────────────────────────

class _PrepArgs {
  final String path;
  final int maxSide;
  const _PrepArgs(this.path, this.maxSide);
}

class PreparedImage {
  final String base64;
  final int width, height;

  /// Content hash of the prepared photo, used as the cache key.
  final String key;
  const PreparedImage(this.base64, this.width, this.height, this.key);
}

PreparedImage _prepareImage(_PrepArgs a) {
  final bytes = File(a.path).readAsBytesSync();
  var decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return PreparedImage(base64Encode(bytes), 0, 0, _fnv(bytes));
  }
  // Phones store photos sideways plus an orientation flag. Apply it, or the AI
  // reads a rotated fridge and mis-identifies things.
  decoded = img.bakeOrientation(decoded);
  final longest = math.max(decoded.width, decoded.height);
  if (longest > a.maxSide) {
    decoded = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: a.maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(decoded, height: a.maxSide, interpolation: img.Interpolation.average);
  }
  final out = img.encodeJpg(decoded, quality: 82);
  return PreparedImage(base64Encode(out), decoded.width, decoded.height, _fnv(out));
}

String _fnv(List<int> bytes) {
  var h = 0xcbf29ce484222325;
  for (final b in bytes) {
    h ^= b;
    h *= 0x100000001b3; // wraps at 64 bits — fine for a cache key
  }
  return h.toRadixString(16);
}
