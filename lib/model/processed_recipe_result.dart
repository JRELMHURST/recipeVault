class ProcessedRecipeResult {
  final String formattedRecipe;
  final String language;
  final bool translationUsed;
  final String originalText;

  ProcessedRecipeResult({
    required this.formattedRecipe,
    required this.language,
    required this.translationUsed,
    required this.originalText,
  });

  factory ProcessedRecipeResult.fromMap(Map<String, dynamic> data) {
    return ProcessedRecipeResult(
      formattedRecipe: data['formattedRecipe'] ?? '',
      originalText: data['originalText'] ?? '',
      translationUsed: data['translationUsed'] ?? false,
      language: data['detectedLanguage'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'formattedRecipe': formattedRecipe,
      'originalText': originalText,
      'translationUsed': translationUsed,
      'detectedLanguage': language,
    };
  }
}
