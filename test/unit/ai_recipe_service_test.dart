import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/recipes/data/ai_recipe_service.dart';

void main() {
  group('AIRecipe.fromJson', () {
    test('maps a complete model response', () {
      final json = jsonDecode('''
      {
        "name": "Creamy Spinach Pasta",
        "description": "Uses up spinach before it turns.",
        "emoji": "🍝",
        "prepTime": "10 min",
        "cookTime": "15 min",
        "servings": 4,
        "usesExpiring": ["Spinach", "Cream"],
        "ingredients": [
          {"item": "Spinach", "amount": "200g"},
          {"item": "Pasta", "amount": "400g"}
        ],
        "steps": ["Boil pasta", "Wilt spinach", "Combine"],
        "tip": "Reserve a cup of pasta water."
      }
      ''') as Map<String, dynamic>;

      final r = AIRecipe.fromJson(json);

      expect(r.name, 'Creamy Spinach Pasta');
      expect(r.emoji, '🍝');
      expect(r.servings, 4);
      expect(r.usesExpiring, ['Spinach', 'Cream']);
      expect(r.ingredients.length, 2);
      expect(r.ingredients.first.item, 'Spinach');
      expect(r.ingredients.first.amount, '200g');
      expect(r.steps.length, 3);
      expect(r.tip, isNotEmpty);
    });

    test('fills defaults when the model omits fields', () {
      final r = AIRecipe.fromJson(<String, dynamic>{});

      expect(r.name, "Chef's Special");
      expect(r.emoji, '🍳');
      expect(r.servings, 2);
      expect(r.prepTime, '?');
      expect(r.usesExpiring, isEmpty);
      expect(r.ingredients, isEmpty);
      expect(r.steps, isEmpty);
    });

    test('accepts a float servings value from the model', () {
      final r = AIRecipe.fromJson({'servings': 4.0});
      expect(r.servings, 4);
    });

    test('tolerates ingredient entries missing item or amount', () {
      final r = AIRecipe.fromJson({
        'ingredients': [
          {'item': 'Rice'},
          {'amount': '2 tbsp'},
        ]
      });
      expect(r.ingredients[0].item, 'Rice');
      expect(r.ingredients[0].amount, '');
      expect(r.ingredients[1].item, '');
      expect(r.ingredients[1].amount, '2 tbsp');
    });
  });

  group('Response envelope extraction', () {
    // The service pulls the first {...} block out of the model's prose.
    // This mirrors that regex so the behaviour is covered without a network call.
    final envelope = RegExp(r'\{[\s\S]*\}');

    test('extracts JSON wrapped in prose and code fences', () {
      const raw = '''
Here you go!

```json
{"name": "Omelette", "servings": 2}
```

Enjoy.
''';
      final match = envelope.firstMatch(raw);
      expect(match, isNotNull);
      final parsed = AIRecipe.fromJson(
          jsonDecode(match!.group(0)!) as Map<String, dynamic>);
      expect(parsed.name, 'Omelette');
    });

    test('finds no JSON in a plain refusal', () {
      expect(envelope.firstMatch('I cannot help with that.'), isNull);
    });
  });
}
