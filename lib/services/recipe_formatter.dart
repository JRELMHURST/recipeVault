import 'package:cloud_functions/cloud_functions.dart';

class RecipeFormatter {
  /// Calls the backend Cloud Function with merged OCR text and returns the formatted recipe.
  static Future<String> formatRecipe(String ocrText) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateRecipeCard',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final result = await callable.call(<String, dynamic>{'ocrText': ocrText});

      return result.data['formattedRecipe'] as String;
    } catch (e) {
      return '⚠️ Failed to format recipe.\n\nError: $e';
    }
  }
}
