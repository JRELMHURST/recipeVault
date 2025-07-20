import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../model/recipe_card_model.dart';

class HiveRecipeService {
  static Box<RecipeCardModel> get box => Hive.box<RecipeCardModel>('recipes');

  static Future<void> save(RecipeCardModel recipe) async {
    await box.put(recipe.id, recipe);
  }

  static List<RecipeCardModel> getAll() => box.values.toList();

  static RecipeCardModel? getById(String id) => box.get(id);

  static Future<void> delete(String id) async {
    await box.delete(id);
  }

  static Future<void> clearAll() async {
    await box.clear();
  }

  /// 🔄 Sync just the favourite field to Firestore
  static Future<void> syncFavouriteToCloud(RecipeCardModel recipe) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || recipe.isGlobal) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('recipes')
        .doc(recipe.id)
        .update({'isFavourite': recipe.isFavourite});

    // ✅ Re-save to ensure local Hive box reflects latest
    await save(recipe);
  }

  /// 🔄 Sync categories field to Firestore
  static Future<void> syncCategoriesToCloud(RecipeCardModel recipe) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || recipe.isGlobal) return; // Only sync user recipes

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('recipes')
        .doc(recipe.id)
        .update({'categories': recipe.categories});

    // ✅ Ensure Hive stays in sync
    await save(recipe);
  }
}
