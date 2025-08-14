// ignore_for_file: unnecessary_cast

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

  /// Optional Firestore-only fields (NOT stored in Hive):
  /// - `translations` holds per-locale formatted blocks (e.g. {'pl': {'formatted': '...'}})
  /// - `availableLocales` lists locales the doc has
  /// - `locale` the base/authoring locale of this doc (e.g. 'en-GB')
  final Map<String, dynamic>? translations;
  final List<String>? availableLocales;
  final String? locale;

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
    this.translations,
    this.availableLocales,
    this.locale,
  }) : createdAt = createdAt ?? DateTime.now(),
       categories = categories ?? const [],
       originalImageUrls = originalImageUrls ?? const [],
       hints = hints ?? const [];

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
    if (translations != null) 'translations': translations,
    if (availableLocales != null) 'availableLocales': availableLocales,
    if (locale != null) 'locale': locale,
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

    // Allow translations to be either Map<String, dynamic> or null
    final Map<String, dynamic>? tr = (json['translations'] is Map)
        ? (json['translations'] as Map).cast<String, dynamic>()
        : null;

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
      translations: tr,
      availableLocales: (json['availableLocales'] as List?)?.cast<String>(),
      locale: json['locale'] as String?,
    );
  }

  RecipeCardModel copyWith({
    String? imageUrl,
    bool? isFavourite,
    List<String>? originalImageUrls,
    List<String>? hints,
    bool? translationUsed,
    List<String>? categories,
    bool? isGlobal,
    String? title,
    List<String>? ingredients,
    List<String>? instructions,
    Map<String, dynamic>? translations,
    List<String>? availableLocales,
    String? locale,
  }) {
    return RecipeCardModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      createdAt: createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      isFavourite: isFavourite ?? this.isFavourite,
      originalImageUrls: originalImageUrls ?? this.originalImageUrls,
      hints: hints ?? this.hints,
      translationUsed: translationUsed ?? this.translationUsed,
      categories: categories ?? this.categories,
      isGlobal: isGlobal ?? this.isGlobal,
      translations: translations ?? this.translations,
      availableLocales: availableLocales ?? this.availableLocales,
      locale: locale ?? this.locale,
    );
  }

  static RecipeCardModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    SnapshotOptions? options,
  ) => RecipeCardModel.fromJson(doc.data()!);

  String toRawJson() => jsonEncode(toJson());
  factory RecipeCardModel.fromRawJson(String str) =>
      RecipeCardModel.fromJson(jsonDecode(str));

  bool get hasImage => imageUrl?.isNotEmpty ?? false;
  bool get isTranslated => categories.contains('Translated');

  String get formattedText {
    final ingredientsStr = ingredients.join('\n• ');
    final instructionsStr = instructions
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    return '## Ingredients\n• $ingredientsStr\n\n## Instructions\n$instructionsStr';
  }

  /// 🔍 Match query against title, ingredients, instructions, and hints
  bool matchesQuery(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        ingredients.any((ing) => ing.toLowerCase().contains(q)) ||
        instructions.any((step) => step.toLowerCase().contains(q)) ||
        hints.any((hint) => hint.toLowerCase().contains(q));
  }

  // ---------------- i18n helpers (UI usage) ----------------

  /// Normalise a BCP‑47 tag from the device to keys we store.
  /// e.g. 'pl-PL' → 'pl'. Keep 'en-GB' special.
  static String normaliseLocaleTag(String raw) {
    final lower = raw.toLowerCase();
    if (lower.startsWith('en-gb')) return 'en-GB';
    return lower.split('-').first;
  }

  /// Return the localised formatted block (ingredients+instructions) for a device tag,
  /// falling back to 'en-GB', 'en', or any first entry if necessary.
  String? formattedForLocaleTag(String bcp47) {
    final tr = translations;
    if (tr == null || tr.isEmpty) return null;

    final norm = normaliseLocaleTag(bcp47);
    final candidate =
        tr[norm] ??
        tr['en-GB'] ??
        tr['en'] ??
        (tr.values.isNotEmpty ? tr.values.first : null);

    if (candidate is Map && candidate['formatted'] is String) {
      return candidate['formatted'] as String;
    }
    if (candidate is String) return candidate; // tolerate string storage
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeCardModel &&
          runtimeType == other.runtimeType &&
          id == other.id);

  @override
  int get hashCode => id.hashCode;
}
