import 'package:hive/hive.dart';
import '../model/recipe_card_model.dart';

class HiveRecipeService {
  static Box<RecipeCardModel> get box => Hive.box<RecipeCardModel>('recipes');

  /// Save or update a recipe card by its ID
  static Future<void> save(RecipeCardModel recipe) async {
    await box.put(recipe.id, recipe);
  }

  /// Retrieve all stored recipes as a list
  static List<RecipeCardModel> getAll() {
    return box.values.toList();
  }

  /// Retrieve a specific recipe by ID
  static RecipeCardModel? getById(String id) {
    return box.get(id);
  }

  /// Delete a recipe by ID
  static Future<void> delete(String id) async {
    await box.delete(id);
  }

  /// Clear all saved recipes
  static Future<void> clearAll() async {
    await box.clear();
  }
}
