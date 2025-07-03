import 'dart:convert';
import 'package:hive/hive.dart';

part 'recipe_card_model.g.dart'; // Generates the adapter

@HiveType(typeId: 0)
class RecipeCardModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final List<String> ingredients;

  @HiveField(4)
  final List<String> instructions;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final String? imageUrl;

  @HiveField(7)
  final List<String> categories;

  @HiveField(8)
  final bool isFavourite;

  @HiveField(9)
  final List<String> originalImageUrls; // ✅ NEW FIELD

  RecipeCardModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.ingredients,
    required this.instructions,
    this.imageUrl,
    this.categories = const [],
    this.isFavourite = false,
    this.originalImageUrls = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'ingredients': ingredients,
    'instructions': instructions,
    'createdAt': createdAt.toIso8601String(),
    if (imageUrl != null) 'imageUrl': imageUrl,
    'categories': categories,
    'isFavourite': isFavourite,
    'originalImageUrls': originalImageUrls,
  };

  factory RecipeCardModel.fromJson(Map<String, dynamic> json) =>
      RecipeCardModel(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        title: json['title'] as String,
        ingredients: List<String>.from(json['ingredients'] ?? []),
        instructions: List<String>.from(json['instructions'] ?? []),
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        imageUrl: json['imageUrl'] as String?,
        categories: List<String>.from(json['categories'] ?? []),
        isFavourite: json['isFavourite'] as bool? ?? false,
        originalImageUrls: List<String>.from(json['originalImageUrls'] ?? []),
      );

  String toRawJson() => jsonEncode(toJson());

  factory RecipeCardModel.fromRawJson(String str) =>
      RecipeCardModel.fromJson(jsonDecode(str));

  RecipeCardModel copyWith({
    bool? isFavourite,
    List<String>? originalImageUrls,
  }) {
    return RecipeCardModel(
      id: id,
      userId: userId,
      title: title,
      ingredients: ingredients,
      instructions: instructions,
      createdAt: createdAt,
      imageUrl: imageUrl,
      categories: categories,
      isFavourite: isFavourite ?? this.isFavourite,
      originalImageUrls: originalImageUrls ?? this.originalImageUrls,
    );
  }
}
