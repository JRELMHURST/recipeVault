class ProcessedRecipeResult {
  final String formattedRecipe;
  final String language;
  final bool translationUsed;
  final String originalText;
  final List<String> imageUrls; // ✅ Add this

  ProcessedRecipeResult({
    required this.formattedRecipe,
    required this.language,
    required this.translationUsed,
    required this.originalText,
    required this.imageUrls, // ✅ Include in constructor
  });

  factory ProcessedRecipeResult.fromMap(Map<String, dynamic> data) {
    return ProcessedRecipeResult(
      formattedRecipe: data['formattedRecipe'] ?? '',
      originalText: data['originalText'] ?? '',
      translationUsed: data['translationUsed'] ?? false,
      language: data['detectedLanguage'] ?? 'unknown',
      imageUrls: List<String>.from(data['imageUrls'] ?? []), // ✅ From map
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'formattedRecipe': formattedRecipe,
      'originalText': originalText,
      'translationUsed': translationUsed,
      'detectedLanguage': language,
      'imageUrls': imageUrls, // ✅ To map
    };
  }
}
