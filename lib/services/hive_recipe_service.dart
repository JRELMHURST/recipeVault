import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../model/recipe_card_model.dart';

class HiveRecipeService {
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  static String get _boxName => 'recipes_$_uid';

  static Box<RecipeCardModel>? _box;

  /// 📦 Call this once before any recipe access
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<RecipeCardModel>(_boxName);
      debugPrint('📦 Hive box opened: $_boxName');
    } else {
      _box = Hive.box<RecipeCardModel>(_boxName);
      debugPrint('📦 Hive box reused: $_boxName');
    }
  }

  static Box<RecipeCardModel> get box {
    if (_box == null) {
      throw HiveError(
        'Box not opened. Did you forget to call HiveRecipeService.init()?',
      );
    }
    return _box!;
  }

  /// ✅ NEW: For external use to get box manually (e.g. in services)
  static Future<Box<RecipeCardModel>> getBox() async {
    await init();
    return box;
  }

  static Future<void> save(RecipeCardModel recipe) async {
    await init();
    await box.put(recipe.id, recipe);
  }

  static Future<List<RecipeCardModel>> getAll() async {
    await init();
    return box.values.toList();
  }

  static Future<RecipeCardModel?> getById(String id) async {
    await init();
    return box.get(id);
  }

  static Future<void> delete(String id) async {
    await init();
    await box.delete(id);
  }

  static Future<void> clearAll() async {
    await init();
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

    await save(recipe); // re-save locally
  }

  /// 🔄 Sync categories field to Firestore
  static Future<void> syncCategoriesToCloud(RecipeCardModel recipe) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || recipe.isGlobal) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('recipes')
        .doc(recipe.id)
        .update({'categories': recipe.categories});

    await save(recipe); // re-save locally
  }

  /// 🧹 Delete recipe box for a specific user (e.g. during account deletion)
  static Future<void> deleteLocalDataForUser(String uid) async {
    final userBoxName = 'recipes_$uid';
    try {
      if (Hive.isBoxOpen(userBoxName)) {
        await Hive.box<RecipeCardModel>(userBoxName).deleteFromDisk();
        debugPrint('🧼 Deleted $userBoxName from disk');
      } else if (await Hive.boxExists(userBoxName)) {
        await Hive.deleteBoxFromDisk(userBoxName);
        debugPrint('🧼 Deleted unopened $userBoxName from disk');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to delete local recipe box for $uid: $e');
    }
  }
}
