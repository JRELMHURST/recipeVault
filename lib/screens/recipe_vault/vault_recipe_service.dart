import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/services/hive_recipe_service.dart';

class VaultRecipeService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _userRecipeCollection {
    final uid = _auth.currentUser?.uid;
    return _firestore.collection('users').doc(uid).collection('recipes');
  }

  /// 🗑️ Delete recipe from Hive, Firestore, and optionally Firebase Storage
  static Future<void> delete(RecipeCardModel recipe) async {
    await HiveRecipeService.delete(recipe.id);
    await _userRecipeCollection.doc(recipe.id).delete();

    if (recipe.imageUrl?.isNotEmpty == true) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(recipe.imageUrl!);
        await ref.delete();
      } catch (_) {
        // Ignore storage deletion errors
      }
    }
  }

  /// 💾 Save recipe to Hive and Firestore (merge mode)
  static Future<void> save(RecipeCardModel recipe) async {
    await HiveRecipeService.save(recipe);
    await _userRecipeCollection
        .doc(recipe.id)
        .set(recipe.toJson(), SetOptions(merge: true));
  }

  /// 📥 Load user recipes from Firestore
  static Future<List<RecipeCardModel>> _loadUserRecipes() async {
    final snapshot = await _userRecipeCollection
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => RecipeCardModel.fromJson(doc.data()))
        .toList();
  }

  /// 🌍 Load global recipes, excluding hidden ones
  static Future<List<RecipeCardModel>> _loadGlobalRecipes() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final hiddenIds =
        (await _firestore
                .collection('users')
                .doc(uid)
                .collection('hiddenGlobalRecipes')
                .get())
            .docs
            .map((doc) => doc.id)
            .toSet();

    final globalSnapshot = await _firestore
        .collection('global_recipes')
        .orderBy('createdAt', descending: true)
        .get();

    return globalSnapshot.docs
        .where((doc) => !hiddenIds.contains(doc.id))
        .map((doc) => RecipeCardModel.fromJson(doc.data()))
        .toList();
  }

  /// 🔁 Load, merge, deduplicate, and cache all recipes to Hive
  static Future<List<RecipeCardModel>> loadAndMergeAllRecipes() async {
    try {
      final userRecipes = await _loadUserRecipes();
      final globalRecipes = await _loadGlobalRecipes();

      final Map<String, RecipeCardModel> mergedMap = {
        for (final r in globalRecipes) r.id: r,
        for (final r in userRecipes) r.id: r,
      };

      final box = await HiveRecipeService.getBox();
      final List<RecipeCardModel> merged = [];

      for (final recipe in mergedMap.values) {
        final local = box.get(recipe.id);
        final enriched = recipe.copyWith(
          isFavourite: local?.isFavourite ?? recipe.isFavourite,
          categories: local?.categories ?? recipe.categories,
        );
        await box.put(recipe.id, enriched);
        merged.add(enriched);
      }

      return merged;
    } catch (e) {
      debugPrint("⚠️ Firestore fetch failed, falling back to Hive: $e");
      return HiveRecipeService.getAll();
    }
  }

  /// ⬇️ Load all recipes into cache
  static Future<void> load() async {
    await loadAndMergeAllRecipes();
    debugPrint('📦 VaultRecipeService.load complete');
  }

  /// 🧹 Clear local Hive recipe cache
  static Future<void> clearCache() async {
    try {
      final box = await HiveRecipeService.getBox();
      await box.clear();
      debugPrint('🧹 VaultRecipeService cache cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear recipe cache: $e');
    }
  }
}
