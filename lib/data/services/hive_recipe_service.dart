// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:recipe_vault/data/models/recipe_card_model.dart';

class HiveRecipeService {
  static String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      throw StateError(
        '❌ No authenticated user — UID required to access Hive recipes.',
      );
    }
    return u.uid;
  }

  static String get _boxName => 'recipes_$_uid';

  static Box<RecipeCardModel>? _box;
  static String? _boxForUid; // which UID the current box belongs to
  static bool _hasLoggedReuse = false;

  /// True if box has been opened successfully.
  static bool get isBoxOpen => _box?.isOpen == true;

  /// Ensure that the currently opened box matches the signed-in user.
  static Future<void> _reopenIfUserChanged() async {
    if (_box != null && _boxForUid == _uid && _box!.isOpen) return;

    // Close previous user's box if necessary
    if (_box?.isOpen == true && _boxForUid != _uid) {
      try {
        await _box!.close();
      } catch (e) {
        debugPrint('⚠️ Failed closing previous user Hive box: $e');
      }
      _box = null;
      _hasLoggedReuse = false;
    }

    // Open (or reuse) the correct box for the current user.
    if (!Hive.isBoxOpen(_boxName)) {
      try {
        _box = await Hive.openBox<RecipeCardModel>(_boxName);
        _boxForUid = _uid;
        debugPrint('📦 Hive box opened: $_boxName');
      } catch (e) {
        debugPrint('⚠️ Error opening Hive box $_boxName: $e');
      }
    } else {
      _box = Hive.box<RecipeCardModel>(_boxName);
      _boxForUid = _uid;
      if (!_hasLoggedReuse) {
        debugPrint('📦 Hive box reused: $_boxName');
        _hasLoggedReuse = true;
      }
    }
  }

  /// Public init – call this early (after sign-in) and before usage.
  static Future<void> init() async {
    await _reopenIfUserChanged(); // throws if no UID
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

  // ───────── CRUD (local) ─────────

  static Future<void> save(RecipeCardModel recipe) async {
    await init();
    await box.put(recipe.id, recipe);
  }

  static Future<void> saveAll(Iterable<RecipeCardModel> recipes) async {
    await init();
    final map = {for (final r in recipes) r.id: r};
    await box.putAll(map);
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

  /// Optional: call when user logs out to fully close the box.
  static Future<void> close() async {
    if (_box?.isOpen == true) {
      try {
        await _box!.close();
      } catch (e) {
        debugPrint('⚠️ Error closing Hive box $_boxName: $e');
      }
    }
    _box = null;
    _boxForUid = null;
    _hasLoggedReuse = false;
  }

  // ───────── Cloud sync helpers (user-owned only) ─────────

  static Future<void> syncFavouriteToCloud(RecipeCardModel recipe) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (recipe.userId != uid) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('recipes')
          .doc(recipe.id)
          .set({'isFavourite': recipe.isFavourite}, SetOptions(merge: true));

      await save(recipe);
    } catch (e) {
      debugPrint('⚠️ Failed to sync favourite to cloud: $e');
    }
  }

  static Future<void> syncCategoriesToCloud(RecipeCardModel recipe) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (recipe.userId != uid) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('recipes')
          .doc(recipe.id)
          .set({'categories': recipe.categories}, SetOptions(merge: true));

      await save(recipe);
    } catch (e) {
      debugPrint('⚠️ Failed to sync categories to cloud: $e');
    }
  }

  // ───────── Cleanup (used by logout/account-deletion) ─────────

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
