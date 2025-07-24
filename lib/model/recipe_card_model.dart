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
    DateTime? createdAt,
    this.imageUrl,
    List<String>? categories,
    this.isFavourite = false,
    List<String>? originalImageUrls,
    List<String>? hints,
    this.translationUsed = false,
    this.isGlobal = false,
  }) : categories = categories ?? const [],
       originalImageUrls = originalImageUrls ?? const [],
       hints = hints ?? const [],
       createdAt = createdAt ?? DateTime.now();

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
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? const []),
      instructions: List<String>.from(json['instructions'] ?? const []),
      createdAt: parsedCreatedAt,
      imageUrl: json['imageUrl'],
      categories: List<String>.from(json['categories'] ?? const []),
      isFavourite: json['isFavourite'] ?? false,
      originalImageUrls: List<String>.from(
        json['originalImageUrls'] ?? const [],
      ),
      hints: List<String>.from(json['hints'] ?? const []),
      translationUsed: json['translationUsed'] ?? false,
      isGlobal: json['isGlobal'] ?? false,
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
    String? imageUrl,
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
      imageUrl: imageUrl ?? this.imageUrl,
      isFavourite: isFavourite ?? this.isFavourite,
      originalImageUrls: originalImageUrls ?? this.originalImageUrls,
      hints: hints ?? this.hints,
      translationUsed: translationUsed ?? this.translationUsed,
      categories: categories ?? this.categories,
      isGlobal: isGlobal ?? this.isGlobal,
    );
  }

  RecipeCardModel withUpdatedImageUrl(String url) {
    return copyWith(imageUrl: url);
  }

  bool get hasImage => imageUrl?.isNotEmpty ?? false;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeCardModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
