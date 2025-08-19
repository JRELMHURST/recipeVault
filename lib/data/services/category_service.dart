// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_vault/auth/uid_provider.dart';

import 'package:recipe_vault/data/models/category_model.dart';
import 'package:recipe_vault/features/recipe_vault/categories.dart';

/// Service for managing recipe categories (user + default/system).
class CategoryService {
  // ─────────────────────────────── constants ───────────────────────────────
  static const List<String> _systemCategories = CategoryKeys.systemOnly;

  /// Deletable starter set we seed locally if empty (NOT system)
  static const List<String> _seedUserDefaults = CategoryKeys.starterUser;

  // ─────────────────────────────── state ───────────────────────────────
  static String get _uid => UIDProvider.requireUid();
  static String get _customBoxName => 'customCategories_$_uid';
  static String get _hiddenDefaultBox => 'hiddenDefaultCategories_$_uid';

  static String? _boxesForUid;

  // ─────────────────────────────── init / bootstrap ───────────────────────────────
  /// Open boxes, migrate legacy values, and ensure user defaults exist locally.
  static Future<void> init() async {
    await _ensureBoxesForCurrentUser();

    final customBox = Hive.box(_customBoxName);

    // 🔁 Migrate legacy String → CategoryModel JSON
    final legacyKeys = customBox.keys
        .where((k) => customBox.get(k) is String)
        .toList();
    for (final key in legacyKeys) {
      final name = customBox.get(key) as String;
      await customBox.put(key, CategoryModel(id: name, name: name).toJson());
      debugPrint('🔁 Migrated legacy category "$name"');
    }

    await _ensureSeedUserDefaultsLocal();
  }

  static Future<void> load() async {
    await getAllCategories(); // warm up
    debugPrint('📂 CategoryService.load() called');
  }

  // ─────────────────────────────── queries / mutations ───────────────────────────────
  static Future<List<CategoryModel>> getAllCategories() async {
    await _ensureBoxesForCurrentUser();
    final box = Hive.box(_customBoxName);
    return box.values
        .whereType<Map>()
        .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> saveCategory(String category) async {
    final name = category.trim();
    if (name.isEmpty || _systemCategories.contains(name)) return;

    await _ensureBoxesForCurrentUser();

    // Save locally
    final box = Hive.box(_customBoxName);
    final alreadyExists = box.values.whereType<Map>().any(
      (e) => e['name'] == name,
    );
    if (!alreadyExists) {
      final model = CategoryModel(id: name, name: name);
      await box.add(model.toJson());
    }

    // Mirror to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('categories')
            .doc(name)
            .set({'name': name}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('⚠️ Firestore saveCategory("$name") failed: $e');
      }
    }
  }

  static Future<void> deleteCategory(String category) async {
    final name = category.trim();
    if (name.isEmpty || _systemCategories.contains(name)) return;

    await _ensureBoxesForCurrentUser();

    // Remove locally
    final box = Hive.box(_customBoxName);
    final key = box.keys.firstWhere(
      (k) => (box.get(k) as Map?)?['name'] == name,
      orElse: () => null,
    );
    if (key != null) {
      await box.delete(key);
    }

    // Remove from Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('categories')
            .doc(name)
            .delete();
      } catch (e) {
        debugPrint('⚠️ Firestore deleteCategory("$name") failed: $e');
      }
    }
  }

  /// Pulls user categories from Firestore and replaces local custom box with them.
  static Future<void> syncFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ Cannot sync categories – no user signed in');
      return;
    }
    await _ensureBoxesForCurrentUser();

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories');

      final snapshot = await ref.get();
      final box = Hive.box(_customBoxName);
      await box.clear();

      for (final doc in snapshot.docs) {
        final name = doc.data()['name'];
        if (name is String && !_systemCategories.contains(name)) {
          await box.add(CategoryModel(id: name, name: name).toJson());
        }
      }

      await _ensureSeedUserDefaultsLocal();
    } catch (e) {
      debugPrint('⚠️ Failed to sync categories from Firestore: $e');
    }
  }

  // ─────────────────────────────── default visibility (legacy) ─────────────────────
  /// (Kept for compatibility in case you still hide defaults in UI somewhere)
  static Future<void> hideDefaultCategory(String category) async {
    if (!_seedUserDefaults.contains(category)) return;
    await _ensureBoxesForCurrentUser();
    final box = Hive.box<String>(_hiddenDefaultBox);
    await box.put(category, category);
  }

  static Future<void> unhideDefaultCategory(String category) async {
    await _ensureBoxesForCurrentUser();
    final box = Hive.box<String>(_hiddenDefaultBox);
    await box.delete(category);
  }

  static Future<List<String>> getHiddenDefaultCategories() async {
    await _ensureBoxesForCurrentUser();
    final box = Hive.box<String>(_hiddenDefaultBox);
    return box.values.toList();
  }

  // ─────────────────────────────── cleanup helpers ───────────────────────────────
  static Future<void> clearCache() async {
    try {
      if (Hive.isBoxOpen(_customBoxName)) {
        await Hive.box(_customBoxName).clear();
        debugPrint('🧹 Cleared $_customBoxName');
      }
      if (Hive.isBoxOpen(_hiddenDefaultBox)) {
        await Hive.box<String>(_hiddenDefaultBox).clear();
        debugPrint('🧹 Cleared $_hiddenDefaultBox');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to clear category cache: $e');
    }
  }

  static Future<void> clearCacheForUser(String uid) async {
    final customBoxName = 'customCategories_$uid';
    final hiddenBoxName = 'hiddenDefaultCategories_$uid';

    try {
      if (Hive.isBoxOpen(customBoxName)) {
        await Hive.box(customBoxName).deleteFromDisk();
      } else if (await Hive.boxExists(customBoxName)) {
        await Hive.deleteBoxFromDisk(customBoxName);
      }

      if (Hive.isBoxOpen(hiddenBoxName)) {
        await Hive.box<String>(hiddenBoxName).deleteFromDisk();
      } else if (await Hive.boxExists(hiddenBoxName)) {
        await Hive.deleteBoxFromDisk(hiddenBoxName);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to clear category data for $uid: $e');
    }
  }

  // ─────────────────────────────── internals ───────────────────────────────
  static Future<void> _ensureBoxesForCurrentUser() async {
    final needsSwitch = _boxesForUid != _uid;

    if (needsSwitch) {
      if (_boxesForUid != null) {
        final prevCustom = 'customCategories_$_boxesForUid';
        final prevHidden = 'hiddenDefaultCategories_$_boxesForUid';
        try {
          if (Hive.isBoxOpen(prevCustom)) await Hive.box(prevCustom).close();
          if (Hive.isBoxOpen(prevHidden)) await Hive.box(prevHidden).close();
        } catch (e) {
          debugPrint('⚠️ Failed closing previous user category boxes: $e');
        }
      }
      _boxesForUid = _uid;
    }

    if (!Hive.isBoxOpen(_customBoxName)) {
      try {
        await Hive.openBox(_customBoxName);
        debugPrint('📦 Opened box: $_customBoxName');
      } catch (e) {
        debugPrint('⚠️ Failed to open $_customBoxName: $e');
      }
    }
    if (!Hive.isBoxOpen(_hiddenDefaultBox)) {
      try {
        await Hive.openBox<String>(_hiddenDefaultBox);
        debugPrint('📦 Opened box: $_hiddenDefaultBox');
      } catch (e) {
        debugPrint('⚠️ Failed to open $_hiddenDefaultBox: $e');
      }
    }
  }

  /// Ensure the seed user categories exist locally (Breakfast/Main/Dessert).
  static Future<void> _ensureSeedUserDefaultsLocal() async {
    final box = Hive.box(_customBoxName);
    final existing = box.values
        .whereType<Map>()
        .map((e) => (e['name'] as String?) ?? '')
        .toSet();

    for (final name in _seedUserDefaults) {
      if (!existing.contains(name)) {
        await box.add(CategoryModel(id: name, name: name).toJson());
      }
    }
  }
}
