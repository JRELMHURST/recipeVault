class ProcessedRecipeResult {
  /// Fully formatted, cleaned recipe (Markdown / rich text).
  final String formattedRecipe;

  /// BCP-47 language code of the detected language, e.g. 'en-GB', 'pl'.
  final String language;

  /// Whether any translation step was used during processing.
  final bool translationUsed;

  /// The original raw text (pre-formatting / pre-translation).
  final String originalText;

  /// Download URLs of any images produced/kept during processing (immutable).
  final List<String> imageUrls;

  /// The user's subscription tier at the time of processing (from backend).
  final String? tier;

  // NOTE: not const (uses List.unmodifiable).
  ProcessedRecipeResult({
    required this.formattedRecipe,
    required this.language,
    required this.translationUsed,
    required this.originalText,
    required List<String> imageUrls,
    this.tier,
  }) : imageUrls = List.unmodifiable(imageUrls);

  /// Convenient empty value.
  factory ProcessedRecipeResult.empty() => ProcessedRecipeResult(
    formattedRecipe: '',
    language: 'unknown',
    translationUsed: false,
    originalText: '',
    imageUrls: const [],
    tier: null,
  );

  /// Map → model. Accepts both 'language' and 'detectedLanguage'.
  factory ProcessedRecipeResult.fromMap(Map<String, dynamic> data) {
    final lang = (data['detectedLanguage'] ?? data['language'] ?? 'unknown')
        .toString();

    final urls =
        (data['imageUrls'] as List?)?.whereType<String>().toList(
          growable: false,
        ) ??
        const <String>[];

    return ProcessedRecipeResult(
      formattedRecipe: (data['formattedRecipe'] ?? '').toString(),
      originalText: (data['originalText'] ?? '').toString(),
      translationUsed: (data['translationUsed'] ?? false) == true,
      language: lang,
      imageUrls: urls,
      tier: data['tier']?.toString(),
    );
  }

  /// Model → Map. Uses 'detectedLanguage' as canonical key.
  Map<String, dynamic> toMap() => {
    'formattedRecipe': formattedRecipe,
    'originalText': originalText,
    'translationUsed': translationUsed,
    'detectedLanguage': language,
    'imageUrls': imageUrls,
    'tier': tier,
  };

  /// Selective immutable update.
  ProcessedRecipeResult copyWith({
    String? formattedRecipe,
    String? language,
    bool? translationUsed,
    String? originalText,
    List<String>? imageUrls,
    String? tier,
  }) {
    return ProcessedRecipeResult(
      formattedRecipe: formattedRecipe ?? this.formattedRecipe,
      language: language ?? this.language,
      translationUsed: translationUsed ?? this.translationUsed,
      originalText: originalText ?? this.originalText,
      imageUrls: imageUrls ?? this.imageUrls,
      tier: tier ?? this.tier,
    );
  }

  /// Merge two results, preferring non-empty fields from [other].
  ProcessedRecipeResult merge(ProcessedRecipeResult other) {
    return ProcessedRecipeResult(
      formattedRecipe: other.formattedRecipe.isNotEmpty
          ? other.formattedRecipe
          : formattedRecipe,
      language: other.language != 'unknown' ? other.language : language,
      translationUsed: translationUsed || other.translationUsed,
      originalText: other.originalText.isNotEmpty
          ? other.originalText
          : originalText,
      imageUrls: other.imageUrls.isNotEmpty ? other.imageUrls : imageUrls,
      tier: other.tier ?? tier,
    );
  }

  // Convenience
  bool get hasImages => imageUrls.isNotEmpty;
  String? get firstImageUrl => hasImages ? imageUrls.first : null;
  bool get isTranslated => translationUsed;

  @override
  String toString() =>
      'ProcessedRecipeResult(lang:$language, translated:$translationUsed, '
      'images:${imageUrls.length}, formatted:${formattedRecipe.length} chars, tier:$tier)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessedRecipeResult &&
          formattedRecipe == other.formattedRecipe &&
          language == other.language &&
          translationUsed == other.translationUsed &&
          originalText == other.originalText &&
          _listEquals(imageUrls, other.imageUrls) &&
          tier == other.tier;

  @override
  int get hashCode =>
      formattedRecipe.hashCode ^
      language.hashCode ^
      translationUsed.hashCode ^
      originalText.hashCode ^
      imageUrls.hashCode ^
      tier.hashCode;

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
