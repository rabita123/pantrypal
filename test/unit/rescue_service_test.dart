import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pantrypal/core/config/backend_config.dart';
import 'package:pantrypal/features/plan/data/rescue_service.dart';

import '../support/fixtures.dart';

const _reply = '''[
 {"name":"Spinach Omelette","emoji":"🍳","description":"Quick and green.","prepMinutes":5,"cookMinutes":8,"servings":2,
  "ingredients":[{"name":"Eggs","quantity":4,"unit":""},{"name":"Spinach","quantity":100,"unit":"g"}],
  "steps":["Whisk eggs","Wilt spinach","Cook"],"kcalPerServing":320,"proteinPerServing":22},
 {"name":"Spinach Pasta","emoji":"🍝","prepMinutes":5,"cookMinutes":15,"servings":2,
  "ingredients":[{"name":"Pasta","quantity":200,"unit":"g"},{"name":"Spinach","quantity":100,"unit":"g"}],
  "steps":["Boil pasta","Stir in spinach"],"kcalPerServing":540,"proteinPerServing":18},
 {"name":"","ingredients":[]},
 {"name":"Green Rice","emoji":"not an emoji","ingredients":[{"name":"Rice"}],"steps":["Cook"]}
]''';

void main() {
  group('parse', () {
    test('turns valid ideas into plannable AI recipes, skipping junk', () {
      final ideas = RescueService.parse(_reply);
      expect(ideas.map((i) => i.recipe.name), ['Spinach Omelette', 'Spinach Pasta', 'Green Rice']);
      final first = ideas.first.recipe;
      expect(first.id, startsWith('ai-'));
      expect(first.isAiMade, isTrue);
      expect(first.ingredients.map((i) => i.name), ['Eggs', 'Spinach']);
      expect(first.totalMinutes, 13);
      expect(first.nutritionLabel, '≈320 kcal · 22g protein');
    });

    test('a bad emoji falls back to a pan', () {
      expect(RescueService.parse(_reply).last.emoji, '🍳');
    });

    test('caps at three ideas', () {
      final four = '[${List.filled(4, '{"name":"A","ingredients":[{"name":"Rice"}]}').join(',')}]';
      expect(RescueService.parse(four), hasLength(3));
    });

    test('nonsense numbers are clamped or dropped', () {
      final r = RescueService.parse(
              '[{"name":"X","servings":400,"kcalPerServing":-5,"cookMinutes":9999,"ingredients":[{"name":"Rice"}]}]')
          .single
          .recipe;
      expect(r.servings, 12);
      expect(r.kcalPerServing, isNull);
      expect(r.cookMinutes, 240);
    });
  });

  group('ideas (network)', () {
    test('sends the picked food first and the rest of the pantry as context', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        // No charset on purpose: the app must still read it as UTF-8.
        return http.Response.bytes(utf8.encode(jsonEncode({'result': _reply})), 200,
            headers: {'content-type': 'application/json'});
      });
      final spinach = item(name: 'Spinach', daysFromNow: 1);
      final rice = item(name: 'Rice', daysFromNow: 200);
      final ideas = await RescueService.ideas(picked: [spinach], pantry: [spinach, rice], servings: 3, client: client);

      expect(ideas, hasLength(3));
      expect(ideas.first.emoji, '🍳', reason: 'emoji survive the round trip');
      expect((sent['picked'] as List).single['name'], 'Spinach');
      expect((sent['pantry'] as List).map((p) => p['name']), ['Rice'], reason: 'picked food is not repeated');
      expect(sent['servings'], 3);
    });

    test('server errors come back in plain words', () async {
      final client = MockClient((_) async => http.Response(jsonEncode({'error': 'Pick at least one food'}), 400));
      expect(
        RescueService.ideas(picked: [item()], pantry: const [], servings: 2, client: client),
        throwsA(isA<BackendException>().having((e) => e.message, 'm', 'Pick at least one food')),
      );
    });

    test('an answer with no usable ideas is a friendly failure, not an empty screen', () async {
      final client = MockClient((_) async => http.Response(jsonEncode({'result': 'sorry'}), 200));
      expect(
        RescueService.ideas(picked: [item()], pantry: const [], servings: 2, client: client),
        throwsA(isA<BackendException>()),
      );
    });
  });
}
