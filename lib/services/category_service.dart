import 'package:flutter/foundation.dart'; // ✅ debugPrint
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_vault/model/category_model.dart';

class CategoryService {
  static const List<String> _systemCategories = ['Favourites', 'Translated'];
  static const List<String> _defaultCategories = [
    'Favourites',
    'Translated',
    'Breakfast',
    'Main',
    'Dessert',
  ];

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  static String get _customBoxName => 'customCategories_$_uid';
  static String get _hiddenDefaultBox => 'hiddenDefaultCategories_$_uid';

  static String? _boxesForUid;

  // ───────────────────────────────── init / bootstrap ─────────────────────────────────

  /// Open boxes for current user, migrate legacy values, and ensure defaults exist locally.
  static Future<void> init() async {
    await _ensureBoxesForCurrentUser();

    final customBox = Hive.box(_customBoxName);

    // 🔁 Migrate legacy string entries -> CategoryModel json
    final legacyKeys = customBox.keys
        .where((k) => customBox.get(k) is String)
        .toList();
    for (final key in legacyKeys) {
      final name = customBox.get(key) as String;
      await customBox.put(key, CategoryModel(id: name, name: name).toJson());
      debugPrint('🔁 Migrated legacy category "$name"');
    }

    // ✅ Ensure default categories exist locally (non‑system ones stored in custom box)
    await _ensureDefaultCategoriesLocal();
  }

  static Future<void> load() async {
    await getAllCategories(); // warms cache / triggers open
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

    final box = Hive.box(_customBoxName);
    final alreadyExists = box.values.whereType<Map>().any(
      (e) => e['name'] == name,
    );
    if (!alreadyExists) {
      final model = CategoryModel(id: name, name: name);
      await box.add(model.toJson());
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(name);

      // merge-safe so first write creates, later writes update
      await ref.set({'name': name}, SetOptions(merge: true));
    }
  }

  static Future<void> deleteCategory(String category) async {
    final name = category.trim();
    if (name.isEmpty || _systemCategories.contains(name)) return;

    await _ensureBoxesForCurrentUser();
    final box = Hive.box(_customBoxName);

    final key = box.keys.firstWhere(
      (k) => (box.get(k) as Map?)?['name'] == name,
      orElse: () => null,
    );
    if (key != null) {
      await box.delete(key);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(name);
      await ref.delete().catchError((_) => null);
    }
  }

  /// Pulls user categories from Firestore and replaces local custom box with them.
  /// (System/default visibility is handled by _hiddenDefaultBox)
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
          final model = CategoryModel(id: name, name: name);
          await box.add(model.toJson());
        }
      }

      // Ensure defaults still exist (local)
      await _ensureDefaultCategoriesLocal();
    } catch (e) {
      debugPrint('⚠️ Failed to sync categories from Firestore: $e');
    }
  }

  // ───────────────────────────── default visibility controls ─────────────────────────────

  static Future<void> hideDefaultCategory(String category) async {
    if (!_defaultCategories.contains(category)) return;
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

  // ───────────────────────────── cleanup helpers ─────────────────────────────

  /// Clear opened boxes (without deleting from disk) – used at logout/reset.
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

  /// Delete boxes for a specific user from disk (e.g. on account deletion).
  static Future<void> clearCacheForUser(String uid) async {
    final customBoxName = 'customCategories_$uid';
    final hiddenBoxName = 'hiddenDefaultCategories_$uid';

    try {
      if (Hive.isBoxOpen(customBoxName)) {
        await Hive.box(customBoxName).deleteFromDisk();
        debugPrint('🧼 Deleted $customBoxName from disk');
      } else if (await Hive.boxExists(customBoxName)) {
        await Hive.deleteBoxFromDisk(customBoxName);
        debugPrint('🧼 Deleted unopened $customBoxName from disk');
      }

      if (Hive.isBoxOpen(hiddenBoxName)) {
        await Hive.box<String>(hiddenBoxName).deleteFromDisk();
        debugPrint('🧼 Deleted $hiddenBoxName from disk');
      } else if (await Hive.boxExists(hiddenBoxName)) {
        await Hive.deleteBoxFromDisk(hiddenBoxName);
        debugPrint('🧼 Deleted unopened $hiddenBoxName from disk');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to clear category data for $uid: $e');
    }
  }

  // ───────────────────────────── internals ─────────────────────────────

  /// Ensure we have the correct boxes opened for the **current** signed-in user.
  static Future<void> _ensureBoxesForCurrentUser() async {
    final needsSwitch = _boxesForUid != _uid;

    if (needsSwitch) {
      // Close previous user boxes if open (avoid cross-user leakage)
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
      await Hive.openBox(_customBoxName);
      debugPrint('📦 Opened box: $_customBoxName');
    }
    if (!Hive.isBoxOpen(_hiddenDefaultBox)) {
      await Hive.openBox<String>(_hiddenDefaultBox);
      debugPrint('📦 Opened box: $_hiddenDefaultBox');
    }
  }

  /// Ensure all default categories appear in the UI:
  /// - System defaults are **not** stored in custom box (they’re implied).
  /// - Non-system defaults (Breakfast/Main/Dessert) are inserted locally if missing.
  static Future<void> _ensureDefaultCategoriesLocal() async {
    final box = Hive.box(_customBoxName);
    final existing = box.values
        .whereType<Map>()
        .map((e) => (e['name'] as String?) ?? '')
        .toSet();

    for (final name in _defaultCategories) {
      if (_systemCategories.contains(name)) continue; // implied
      if (!existing.contains(name)) {
        await box.add(CategoryModel(id: name, name: name).toJson());
      }
    }
  }
}
