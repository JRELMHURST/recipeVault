// ignore_for_file: unnecessary_null_checks

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/services/hive_recipe_service.dart';

/// User-only Vault data layer (no global/community).
/// - Persists to Hive for instant UI + offline
/// - Mirrors to Firestore (merge)
/// - Optional Storage cleanup on delete
class VaultRecipeService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _vaultSub;

  static CollectionReference<Map<String, dynamic>> get _userRecipeCollection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('No authenticated user to access user recipes');
    }
    return _firestore.collection('users').doc(uid).collection('recipes');
  }

  // ─────────────────────────────── public API ───────────────────────────────

  /// 🗑 Delete recipe from Hive, Firestore, and (if present) Firebase Storage.
  static Future<void> delete(RecipeCardModel recipe) async {
    await HiveRecipeService.delete(recipe.id);

    try {
      await _userRecipeCollection.doc(recipe.id).delete();
    } catch (e) {
      debugPrint('⚠️ Firestore deletion failed for ${recipe.id}: $e');
    }

    final url = recipe.imageUrl;
    if (url != null && url.isNotEmpty) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (e) {
        // Swallow storage errors (file may already be gone / not ours)
        debugPrint('ℹ️ Storage delete skipped for ${recipe.id}: $e');
      }
    }
  }

  /// 💾 Save recipe to Hive and Firestore (merge mode).
  static Future<void> save(RecipeCardModel recipe) async {
    await HiveRecipeService.save(recipe);
    try {
      await _userRecipeCollection
          .doc(recipe.id)
          .set(recipe.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Firestore save failed for ${recipe.id}: $e');
    }
  }

  /// ⬇ Loads **user** recipes from Firestore, merges with local (favourites/categories),
  /// writes merged back to Hive, and returns the merged list.
  static Future<List<RecipeCardModel>> loadAndMergeAllRecipes() async {
    try {
      await HiveRecipeService.init(); // ensure the box is open

      final userRecipes = await _loadUserRecipes();
      final box = await HiveRecipeService.getBox();

      final mergedList = <RecipeCardModel>[];
      for (final recipe in userRecipes) {
        final local = box.get(recipe.id);
        final enriched = recipe.copyWith(
          isFavourite: local?.isFavourite ?? recipe.isFavourite,
          categories: local?.categories ?? recipe.categories,
        );
        await box.put(recipe.id, enriched);
        mergedList.add(enriched);
      }

      return mergedList;
    } catch (e) {
      debugPrint('⚠️ Firestore fetch failed, falling back to Hive: $e');
      return HiveRecipeService.getAll();
    }
  }

  /// Convenience boot method used by screens.
  static Future<void> load() async {
    await loadAndMergeAllRecipes();
    debugPrint('📦 VaultRecipeService.load complete');
  }

  /// 📡 Listen to **user** recipe changes and trigger a refresh callback.
  static void listenToVaultChanges(void Function() onUpdate) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('⚠️ Cannot listen to vault changes – no user signed in');
      return;
    }

    _vaultSub?.cancel();
    try {
      _vaultSub = _userRecipeCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
            (_) => onUpdate(),
            onError: (err) => debugPrint('⚠️ Vault snapshot error: $err'),
            cancelOnError: true,
          );
      debugPrint('📡 Firestore vault listener started for $uid');
    } catch (e) {
      debugPrint('⚠️ Failed to start vault listener: $e');
    }
  }

  static void cancelVaultListener() {
    _vaultSub?.cancel();
    _vaultSub = null;
    debugPrint('📡 Firestore vault listener cancelled');
  }

  /// Clears the per-user Hive cache box.
  static Future<void> clearCache() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _closeAndDeleteBox<RecipeCardModel>('recipes_$uid');
  }

  /// Update text content only (title/ingredients/instructions) for an existing recipe.
  static Future<void> updateTextContent({
    required String recipeId,
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
  }) async {
    try {
      await HiveRecipeService.init();
      final box = await HiveRecipeService.getBox();
      final recipe = box.get(recipeId);
      if (recipe == null) {
        debugPrint('⚠️ Recipe not found in Hive: $recipeId');
        return;
      }

      final updated = recipe.copyWith(
        title: title,
        ingredients: ingredients,
        instructions: instructions,
      );

      await HiveRecipeService.save(updated);

      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('recipes')
            .doc(recipeId)
            .set(updated.toJson(), SetOptions(merge: true));
      }

      debugPrint('✅ Recipe text updated: $recipeId');
    } catch (e) {
      debugPrint('⚠️ Failed to update recipe text: $e');
    }
  }

  // ─────────────────────────────── internals ───────────────────────────────

  static Future<List<RecipeCardModel>> _loadUserRecipes() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return [];

      final snapshot = await _userRecipeCollection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RecipeCardModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Failed to fetch user recipes: $e');
      return [];
    }
  }

  // No global/community merges by design.

  static Future<void> _closeAndDeleteBox<T>(String name) async {
    try {
      if (Hive.isBoxOpen(name)) {
        final box = Hive.box<T>(name);
        if (box.isOpen) await box.close();
      }
      await Hive.deleteBoxFromDisk(name);
      if (kDebugMode) {
        print('📦 Cleared Hive box: $name');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error clearing Hive box $name: $e');
      }
    }
  }
}
