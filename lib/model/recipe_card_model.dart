import 'dart:convert';

class RecipeCardModel {
  final String id; // Unique ID (UUID or Firestore doc ID)
  final String userId; // Firebase Auth user id
  final String title;
  final List<String> ingredients;
  final List<String> instructions;
  final DateTime createdAt;

  RecipeCardModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.ingredients,
    required this.instructions,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // JSON for Firestore or local storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'ingredients': ingredients,
    'instructions': instructions,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RecipeCardModel.fromJson(Map<String, dynamic> json) =>
      RecipeCardModel(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '', // For backwards compat
        title: json['title'] as String,
        ingredients: List<String>.from(json['ingredients'] ?? []),
        instructions: List<String>.from(json['instructions'] ?? []),
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );

  // For storage as string (convenience)
  String toRawJson() => jsonEncode(toJson());

  factory RecipeCardModel.fromRawJson(String str) =>
      RecipeCardModel.fromJson(jsonDecode(str));
}
