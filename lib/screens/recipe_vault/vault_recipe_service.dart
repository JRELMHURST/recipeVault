// ignore_for_file: unnecessary_null_checks

import 'dart:async';

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

  static StreamSubscription? _vaultSub;

  static CollectionReference<Map<String, dynamic>> get _userRecipeCollection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('No authenticated user to access user recipes');
    }
    return _firestore.collection('users').doc(uid).collection('recipes');
  }

  /// 🗑️ Delete recipe from Hive, Firestore, and optionally Firebase Storage
  static Future<void> delete(RecipeCardModel recipe) async {
    await HiveRecipeService.delete(recipe.id);
    try {
      await _userRecipeCollection.doc(recipe.id).delete();
    } catch (e) {
      debugPrint("⚠️ Firestore deletion failed: $e");
    }

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
    try {
      await _userRecipeCollection
          .doc(recipe.id)
          .set(recipe.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint("⚠️ Firestore save failed: $e");
    }
  }

  /// 📥 Load user recipes from Firestore
  static Future<List<RecipeCardModel>> _loadUserRecipes() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('recipes')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RecipeCardModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint("⚠️ Failed to fetch user recipes: $e");
      return [];
    }
  }

  /// 🌍 Load global recipes, excluding hidden ones
  static Future<List<RecipeCardModel>> _loadGlobalRecipes() async {
    try {
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
    } catch (e) {
      debugPrint("⚠️ Failed to fetch global recipes: $e");
      return [];
    }
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

  /// 📡 Listen to Firestore recipe changes
  static void listenToVaultChanges(void Function() onUpdate) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint("⚠️ Cannot listen to vault changes – no user signed in");
      return;
    }

    _vaultSub?.cancel();

    try {
      _vaultSub = _firestore
          .collection('users')
          .doc(uid)
          .collection('recipes')
          .snapshots()
          .listen(
            (_) => onUpdate(),
            onError: (error) => debugPrint('⚠️ Vault snapshot error: $error'),
            cancelOnError: true,
          );
      debugPrint('📡 Firestore vault listener started');
    } catch (e) {
      debugPrint("⚠️ Failed to start vault listener: $e");
    }
  }

  /// ❌ Cancel Firestore recipe listener
  static void cancelVaultListener() {
    _vaultSub?.cancel();
    _vaultSub = null;
    debugPrint('📡 Firestore vault listener cancelled');
  }

  /// 🧹 Clear local Hive recipe cache
  static Future<void> clearCache() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _closeAndDeleteBox<RecipeCardModel>('recipes_$uid');
  }

  /// 🧰 Safely close and delete a Hive box
  static Future<void> _closeAndDeleteBox<T>(String name) async {
    try {
      if (Hive.isBoxOpen(name)) {
        final box = Hive.box<T>(name);
        if (box.isOpen) await box.close();
      }
      await Hive.deleteBoxFromDisk(name);
      if (kDebugMode) print('📦 Cleared Hive box: $name');
    } catch (e) {
      if (kDebugMode) print('⚠️ Error clearing Hive box $name: $e');
    }
  }
}
