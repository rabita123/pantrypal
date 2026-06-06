import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

class FridgeScanService {
  // Your Supabase project URL and anon key — safe to be in the app.
  // Get these from: supabase.com → your project → Settings → API
  static const _supabaseUrl = 'https://hwkaxobdmyiyodtgrpio.supabase.co';
  static const _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3a2F4b2JkbXlpeW9kdGdycGlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyMjEyNjcsImV4cCI6MjA5NTc5NzI2N30.naKIQOSgMjP_-yM5fiNpiwpkSB2SuNHha9uVSTJF4Ug';

  static Future<List<Map<String, dynamic>>> analyzeImage(String imagePath) async {
    final base64Image = await _prepareImage(imagePath);
    final ext = imagePath.toLowerCase();
    final mediaType = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';

    final response = await http.post(
      Uri.parse('$_supabaseUrl/functions/v1/analyze-fridge'),
      headers: {
        'Authorization': 'Bearer $_supabaseAnonKey',
        'apikey': _supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'image': base64Image, 'mediaType': mediaType}),
    ).timeout(const Duration(seconds: 40));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Server error ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = data['result'] as String? ?? '';
    return _parseItems(rawText);
  }

  // Resize to max 1024px wide — keeps payload small and fast
  static Future<String> _prepareImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return base64Encode(bytes);

    final resized = decoded.width > 1024
        ? img.copyResize(decoded, width: 1024)
        : decoded;

    return base64Encode(img.encodeJpg(resized, quality: 85));
  }

  static List<Map<String, dynamic>> _parseItems(String rawText) {
    final match = RegExp(r'\[[\s\S]*\]').firstMatch(rawText);
    if (match == null) return [];

    final List<dynamic> raw;
    try {
      raw = jsonDecode(match.group(0)!) as List<dynamic>;
    } catch (_) {
      return [];
    }

    return raw.whereType<Map<String, dynamic>>().map((item) {
      final categoryStr = (item['category'] as String? ?? 'other').toLowerCase();
      final category = FoodCategory.fromString(categoryStr);
      final shelfLife = (item['estimatedExpiryDays'] as num?)?.toInt()
          ?? AppConstants.defaultShelfLife[categoryStr]
          ?? 14;

      return <String, dynamic>{
        'name': _toTitleCase(item['name'] as String? ?? 'Item'),
        'category': category,
        'quantity': (item['quantity'] as num?)?.toDouble() ?? 1.0,
        'unit': item['unit'] as String? ?? 'item',
        'price': null,
        'estimatedExpiryDays': shelfLife,
      };
    }).toList();
  }

  static String _toTitleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
