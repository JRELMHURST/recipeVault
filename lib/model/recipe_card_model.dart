import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<String> originalImageUrls;

  @HiveField(10)
  final List<String> hints;

  @HiveField(11)
  final bool translationUsed;

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
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 🔁 Convert to Firestore/JSON-safe map
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
  };

  /// 🔁 Create from Firestore snapshot or JSON
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
    );
  }

  /// 🔁 Needed for Firestore reads (e.g. from `doc.data()`)
  factory RecipeCardModel.fromMap(Map<String, dynamic> map) {
    return RecipeCardModel.fromJson(map);
  }

  /// 📦 Serialise to a raw JSON string
  String toRawJson() => jsonEncode(toJson());

  /// 📥 Deserialize from raw JSON string
  factory RecipeCardModel.fromRawJson(String str) =>
      RecipeCardModel.fromJson(jsonDecode(str));

  /// 🛠️ Clone with updates
  RecipeCardModel copyWith({
    bool? isFavourite,
    List<String>? originalImageUrls,
    List<String>? hints,
    bool? translationUsed,
    required List<String> categories,
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
      hints: hints ?? this.hints,
      translationUsed: translationUsed ?? this.translationUsed,
    );
  }

  /// 📝 For rendering in shared screens etc
  String get formattedText {
    final ingredientsStr = ingredients.join('\n• ');
    final instructionsStr = instructions
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n\n');

    return 'Ingredients:\n• $ingredientsStr\n\nInstructions:\n$instructionsStr';
  }

  /// ✅ Computed flag for filtering UI
  bool get isTranslated => categories.contains('Translated');
}
