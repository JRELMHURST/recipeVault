import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/services/hive_recipe_service.dart';

class VaultRecipeService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get userRecipeCollection {
    final uid = _auth.currentUser?.uid;
    return _firestore.collection('users').doc(uid).collection('recipes');
  }

  /// Delete recipe from Hive, Firestore, and optionally Firebase Storage
  static Future<void> delete(RecipeCardModel recipe) async {
    await HiveRecipeService.delete(recipe.id);
    await userRecipeCollection.doc(recipe.id).delete();

    if (recipe.imageUrl?.isNotEmpty == true) {
      final ref = FirebaseStorage.instance.refFromURL(recipe.imageUrl!);
      await ref.delete().catchError((_) => null);
    }
  }

  /// Save recipe to Hive and Firestore (merge mode)
  static Future<void> save(RecipeCardModel recipe) async {
    await HiveRecipeService.save(recipe);
    await userRecipeCollection
        .doc(recipe.id)
        .set(recipe.toJson(), SetOptions(merge: true));
  }

  /// Load user recipes from Firestore
  static Future<List<RecipeCardModel>> loadUserRecipes() async {
    final snapshot = await userRecipeCollection
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => RecipeCardModel.fromJson(doc.data()))
        .toList();
  }

  /// Load global recipes, excluding hidden ones
  static Future<List<RecipeCardModel>> loadGlobalRecipes() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final hiddenSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('hiddenGlobalRecipes')
        .get();

    final hiddenIds = hiddenSnapshot.docs.map((doc) => doc.id).toSet();

    final globalSnapshot = await _firestore
        .collection('global_recipes')
        .orderBy('createdAt', descending: true)
        .get();

    return globalSnapshot.docs
        .where((doc) => !hiddenIds.contains(doc.id))
        .map((doc) => RecipeCardModel.fromJson(doc.data()))
        .toList();
  }

  /// Load, merge, deduplicate, and cache all recipes to Hive
  static Future<List<RecipeCardModel>> loadAndMergeAllRecipes() async {
    try {
      final userRecipes = await loadUserRecipes();
      final globalRecipes = await loadGlobalRecipes();

      final Map<String, RecipeCardModel> mergedMap = {};

      for (final recipe in globalRecipes) {
        mergedMap[recipe.id] = recipe;
      }

      for (final recipe in userRecipes) {
        mergedMap[recipe.id] = recipe;
      }

      final List<RecipeCardModel> merged = [];
      for (final recipe in mergedMap.values) {
        final local = HiveRecipeService.getById(recipe.id);
        final enriched = recipe.copyWith(
          isFavourite: local?.isFavourite ?? recipe.isFavourite,
          categories: local?.categories ?? recipe.categories,
        );
        await HiveRecipeService.save(enriched);
        merged.add(enriched);
      }

      return merged;
    } catch (e) {
      debugPrint("⚠️ Failed to load from Firestore: $e");
      return HiveRecipeService.getAll();
    }
  }

  /// Load recipes from Firestore and cache to Hive
  static Future<void> load() async {
    await loadAndMergeAllRecipes();
    debugPrint('📦 VaultRecipeService.load complete');
  }

  /// Clear cached Hive recipe data (used on logout or reset)
  static Future<void> clearCache() async {
    try {
      final box = await Hive.openBox<RecipeCardModel>('recipes');
      await box.clear();
      if (kDebugMode) {
        print('🧹 VaultRecipeService cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to clear recipe cache: $e');
      }
    }
  }
}
