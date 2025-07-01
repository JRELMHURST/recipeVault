class RecipeFormatter {
  /// Calls your backend cloud function with image URLs to get OCR & formatted recipe text.
  ///
  /// Replace the stub implementation with an actual call to Firebase Functions or another backend.
  static Future<String> formatRecipe(List<String> imageUrls) async {
    // TODO: Replace this with actual backend call using Cloud Functions, e.g.:
    // final callable = FirebaseFunctions.instance.httpsCallable('formatRecipeText');
    // final result = await callable.call(<String, dynamic>{'imageUrls': imageUrls});
    // return result.data as String;

    // Simulated delay and dummy recipe text for now
    await Future.delayed(const Duration(seconds: 2));
    return '''
Title: Sample Recipe

Ingredients:
- Example Ingredient 1
- Example Ingredient 2

Instructions:
1. Do this
2. Do that
''';
  }
}
