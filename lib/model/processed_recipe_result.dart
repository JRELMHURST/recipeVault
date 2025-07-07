class ProcessedRecipeResult {
  final String formattedRecipe;
  final String language;
  final bool translationUsed;
  final String originalText;
  final List<String> imageUrls;

  ProcessedRecipeResult({
    required this.formattedRecipe,
    required this.language,
    required this.translationUsed,
    required this.originalText,
    required this.imageUrls,
  });

  factory ProcessedRecipeResult.fromMap(Map<String, dynamic> data) {
    return ProcessedRecipeResult(
      formattedRecipe: data['formattedRecipe'] ?? '',
      originalText: data['originalText'] ?? '',
      translationUsed: data['translationUsed'] ?? false,
      language: data['detectedLanguage'] ?? 'unknown',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'formattedRecipe': formattedRecipe,
      'originalText': originalText,
      'translationUsed': translationUsed,
      'detectedLanguage': language,
      'imageUrls': imageUrls,
    };
  }

  /// Allows selective override of fields.
  ProcessedRecipeResult copyWith({
    String? formattedRecipe,
    String? language,
    bool? translationUsed,
    String? originalText,
    List<String>? imageUrls,
  }) {
    return ProcessedRecipeResult(
      formattedRecipe: formattedRecipe ?? this.formattedRecipe,
      language: language ?? this.language,
      translationUsed: translationUsed ?? this.translationUsed,
      originalText: originalText ?? this.originalText,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }
}
