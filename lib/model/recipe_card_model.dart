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

  /// Firestore-only (NOT stored in Hive)
  final Map<String, dynamic>? translations;
  final List<String>? availableLocales;
  final String? locale;

  RecipeCardModel({
    required this.id,
    required this.userId,
    required this.title,
    required List<String> ingredients,
    required List<String> instructions,
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
       // Freeze lists to avoid accidental mutation bugs in UI code.
       ingredients = List.unmodifiable(ingredients),
       instructions = List.unmodifiable(instructions),
       categories = List.unmodifiable(categories ?? const []),
       originalImageUrls = List.unmodifiable(originalImageUrls ?? const []),
       hints = List.unmodifiable(hints ?? const []);

  // ---------------- Serialization ----------------

  /// Model → JSON (for Firestore). Use Timestamp for server-side ordering.
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'ingredients': ingredients,
    'instructions': instructions,
    'createdAt': Timestamp.fromDate(createdAt),
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

  /// JSON/Firestore → Model (tolerant to both Timestamp and ISO strings).
  factory RecipeCardModel.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    DateTime parsedCreatedAt;
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else if (rawCreatedAt is num) {
      // Fall back for epoch ms if ever present
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(
        rawCreatedAt.toInt(),
      );
    } else {
      parsedCreatedAt = DateTime.now();
    }

    final Map<String, dynamic>? tr = (json['translations'] is Map)
        ? (json['translations'] as Map).cast<String, dynamic>()
        : null;

    List<String> asStringList(dynamic v) => (v as List? ?? const <dynamic>[])
        .whereType()
        .map((e) => e.toString())
        .toList(growable: false);

    return RecipeCardModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      ingredients: asStringList(json['ingredients']),
      instructions: asStringList(json['instructions']),
      createdAt: parsedCreatedAt,
      imageUrl: json['imageUrl'] as String?,
      categories: asStringList(json['categories']),
      isFavourite: (json['isFavourite'] ?? false) == true,
      originalImageUrls: asStringList(json['originalImageUrls']),
      hints: asStringList(json['hints']),
      translationUsed: (json['translationUsed'] ?? false) == true,
      isGlobal: (json['isGlobal'] ?? false) == true,
      translations: tr,
      availableLocales: (json['availableLocales'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      locale: json['locale'] as String?,
    );
  }

  static RecipeCardModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    SnapshotOptions? options,
  ) => RecipeCardModel.fromJson(doc.data()!);

  String toRawJson() => jsonEncode(toJson());
  factory RecipeCardModel.fromRawJson(String str) =>
      RecipeCardModel.fromJson(jsonDecode(str));

  // ---------------- Convenience ----------------

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
    DateTime? createdAt,
  }) {
    return RecipeCardModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      createdAt: createdAt ?? this.createdAt,
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

  /// Normalise a BCP-47 tag from the device to keys we store.
  /// e.g. 'pl-PL' → 'pl'. Keep 'en-GB' special.
  static String normaliseLocaleTag(String raw) {
    final lower = raw.toLowerCase();
    if (lower.startsWith('en-gb')) return 'en-GB';
    return lower.split('-').first;
  }

  /// Return the localised formatted block for a device tag,
  /// falling back to 'en-GB', 'en', or any first entry.
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
    if (candidate is String) return candidate;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RecipeCardModel && id == other.id);

  @override
  int get hashCode => id.hashCode;
}
