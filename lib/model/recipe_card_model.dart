import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'recipe_card_model.g.dart';

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
  final List<String> originalImageUrls;

  @HiveField(10)
  final List<String> hints;

  @HiveField(11)
  final bool translationUsed;

  @HiveField(12)
  final bool isGlobal;

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
    this.hints = const [],
    this.translationUsed = false,
    this.isGlobal = false,
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
    'hints': hints,
    'translationUsed': translationUsed,
    'isGlobal': isGlobal,
  };

  factory RecipeCardModel.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    DateTime parsedCreatedAt;

    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return RecipeCardModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String,
      ingredients: List<String>.from(json['ingredients'] ?? []),
      instructions: List<String>.from(json['instructions'] ?? []),
      createdAt: parsedCreatedAt,
      imageUrl: json['imageUrl'] as String?,
      categories: List<String>.from(json['categories'] ?? []),
      isFavourite: json['isFavourite'] as bool? ?? false,
      originalImageUrls: List<String>.from(json['originalImageUrls'] ?? []),
      hints: List<String>.from(json['hints'] ?? []),
      translationUsed: json['translationUsed'] as bool? ?? false,
      isGlobal: json['isGlobal'] as bool? ?? false,
    );
  }

  factory RecipeCardModel.fromMap(Map<String, dynamic> map) =>
      RecipeCardModel.fromJson(map);

  static RecipeCardModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    SnapshotOptions? options,
  ) {
    final data = doc.data()!;
    return RecipeCardModel.fromJson(data);
  }

  String toRawJson() => jsonEncode(toJson());

  factory RecipeCardModel.fromRawJson(String str) =>
      RecipeCardModel.fromJson(jsonDecode(str));

  RecipeCardModel copyWith({
    bool? isFavourite,
    List<String>? originalImageUrls,
    List<String>? hints,
    bool? translationUsed,
    List<String>? categories,
    bool? isGlobal,
  }) {
    return RecipeCardModel(
      id: id,
      userId: userId,
      title: title,
      ingredients: ingredients,
      instructions: instructions,
      createdAt: createdAt,
      imageUrl: imageUrl,
      categories: categories ?? this.categories,
      isFavourite: isFavourite ?? this.isFavourite,
      originalImageUrls: originalImageUrls ?? this.originalImageUrls,
      hints: hints ?? this.hints,
      translationUsed: translationUsed ?? this.translationUsed,
      isGlobal: isGlobal ?? this.isGlobal,
    );
  }

  String get formattedText {
    final ingredientsStr = ingredients.join('\n• ');
    final instructionsStr = instructions
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n\n');

    return 'Ingredients:\n• $ingredientsStr\n\nInstructions:\n$instructionsStr';
  }

  bool get isTranslated => categories.contains('Translated');
}
