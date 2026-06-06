import 'package:equatable/equatable.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

enum DietaryTag {
  vegan('Vegan', '🌱'),
  vegetarian('Vegetarian', '🥗'),
  glutenFree('Gluten-Free', '🌾'),
  dairyFree('Dairy-Free', '🥛'),
  keto('Keto', '🥑'),
  highProtein('High Protein', '💪'),
  nutFree('Nut-Free', '🥜'),
  halal('Halal', '☪️'),
  kidFriendly('Kid-Friendly', '👶');

  final String label;
  final String emoji;
  const DietaryTag(this.label, this.emoji);

  static DietaryTag? fromString(String s) {
    return DietaryTag.values.cast<DietaryTag?>().firstWhere(
      (e) => e?.name == s,
      orElse: () => null,
    );
  }
}

enum Cuisine {
  any('Any', '🌍'),
  bangladeshi('Bangladeshi', '🇧🇩'),
  indian('Indian', '🇮🇳'),
  italian('Italian', '🇮🇹'),
  asian('Asian', '🥢'),
  middleEastern('Middle Eastern', '🫙'),
  american('American', '🍔'),
  mexican('Mexican', '🌮'),
  mediterranean('Mediterranean', '🫒'),
  other('Other', '🍽️');

  final String label;
  final String emoji;
  const Cuisine(this.label, this.emoji);

  static Cuisine fromString(String s) {
    return Cuisine.values.firstWhere(
      (e) => e.name == s,
      orElse: () => Cuisine.other,
    );
  }
}

class RecipeIngredient extends Equatable {
  final String name;
  final double quantity;
  final String unit;
  final FoodCategory category;
  final String? notes;

  const RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.notes,
  });

  RecipeIngredient scaleBy(double factor) => RecipeIngredient(
        name: name,
        quantity: quantity * factor,
        unit: unit,
        category: category,
        notes: notes,
      );

  String get displayQuantity {
    final q = quantity;
    if (q == q.truncateToDouble() && q < 1000) {
      return q.toInt().toString();
    }
    return q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(1);
  }

  @override
  List<Object?> get props => [name, quantity, unit];
}

class Recipe extends Equatable {
  final String id;
  final String name;
  final String? description;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final Set<DietaryTag> dietaryTags;
  final Cuisine cuisine;
  final String? imageUrl;
  final bool isFavorite;
  final DateTime createdAt;

  const Recipe({
    required this.id,
    required this.name,
    this.description,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.ingredients,
    required this.steps,
    required this.dietaryTags,
    required this.cuisine,
    this.imageUrl,
    required this.isFavorite,
    required this.createdAt,
  });

  int get totalMinutes => prepMinutes + cookMinutes;

  String get timeLabel {
    final total = totalMinutes;
    if (total < 60) return '${total}min';
    final h = total ~/ 60;
    final m = total % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  Recipe copyWith({
    String? name,
    String? description,
    int? servings,
    int? prepMinutes,
    int? cookMinutes,
    List<RecipeIngredient>? ingredients,
    List<String>? steps,
    Set<DietaryTag>? dietaryTags,
    Cuisine? cuisine,
    String? imageUrl,
    bool? isFavorite,
  }) {
    return Recipe(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      servings: servings ?? this.servings,
      prepMinutes: prepMinutes ?? this.prepMinutes,
      cookMinutes: cookMinutes ?? this.cookMinutes,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      cuisine: cuisine ?? this.cuisine,
      imageUrl: imageUrl ?? this.imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, isFavorite];
}
