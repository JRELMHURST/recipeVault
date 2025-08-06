import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../model/recipe_card_model.dart';

class HiveRecipeService {
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  static String get _boxName => 'recipes_$_uid';

  static Box<RecipeCardModel>? _box;
  static bool _hasLoggedReuse = false;

  /// 📦 True if box has been opened successfully
  static bool get isBoxOpen => _box?.isOpen == true;

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<RecipeCardModel>(_boxName);
      debugPrint('📦 Hive box opened: $_boxName');
    } else {
      _box = Hive.box<RecipeCardModel>(_boxName);
      if (!_hasLoggedReuse) {
        debugPrint('📦 Hive box reused: $_boxName');
        _hasLoggedReuse = true;
      }
    }
  }

  static void _throwIfNotInitialised() {
    if (_box == null) {
      throw HiveError(
        'Box not opened. Did you forget to call HiveRecipeService.init()?',
      );
    }
  }

  static Box<RecipeCardModel> get box {
    _throwIfNotInitialised();
    return _box!;
  }

  static Future<Box<RecipeCardModel>> getBox() async {
    await init();
    return box;
  }

  static Future<void> save(RecipeCardModel recipe) async {
    await init();
    box.put(recipe.id, recipe);
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
    box.delete(id);
  }

  static Future<void> clearAll() async {
    await init();
    box.clear();
  }

  static Future<void> syncFavouriteToCloud(RecipeCardModel recipe) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || recipe.isGlobal) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('recipes')
        .doc(recipe.id)
        .update({'isFavourite': recipe.isFavourite});

    await save(recipe);
  }

  static Future<void> syncCategoriesToCloud(RecipeCardModel recipe) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || recipe.isGlobal) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('recipes')
        .doc(recipe.id)
        .update({'categories': recipe.categories});

    await save(recipe);
  }

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
