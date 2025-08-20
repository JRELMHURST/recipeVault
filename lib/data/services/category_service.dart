// lib/data/services/category_service.dart
// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:recipe_vault/data/models/category_model.dart';
import 'package:recipe_vault/features/recipe_vault/categories.dart';

/// Service for managing recipe categories (user + default/system).
/// - Never opens boxes without a signed-in user
/// - Switches boxes on auth changes driven by AppBootstrap.onAuthChanged(uid)
/// - Firestore mirror at /users/{uid}/categories/{name}
/// - Hidden defaults are mirrored at /users/{uid}/prefs/app.hiddenDefaultCategories
class CategoryService {
  // ─────────────────────────────── constants ───────────────────────────────
  static const List<String> _systemCategories = CategoryKeys.systemOnly;
  static const List<String> _seedUserDefaults = CategoryKeys.starterUser;

  // ─────────────────────────────── deps / state ─────────────────────────────
  static final _auth = FirebaseAuth.instance;
  static final _fs = FirebaseFirestore.instance;

  static String? _openForUid; // which user's boxes are currently open

  static String _customBoxName(String uid) => 'customCategories_$uid';
  static String _hiddenDefaultBox(String uid) => 'hiddenDefaultCategories_$uid';

  // ─────────────────────────────── lifecycle ────────────────────────────────
  /// Call once at app startup. No auth listeners here—bootstrap owns that.
  static Future<void> init() async {
    // no-op; boxes are opened/closed via onAuthChanged(uid).
  }

  /// App bootstrap must call this whenever FirebaseAuth state changes.
  static Future<void> onAuthChanged(String? uid) => _switchUser(uid);

  /// Optional warm-up hook for older call sites.
  static Future<void> load() async {
    final uid = _requireUserOrNull();
    if (uid == null) return;
    await _ensureBoxes(uid);
    if (kDebugMode) debugPrint('📂 CategoryService.load() complete');
  }

  /// Optional: dispose any open user boxes (e.g., on app quit).
  static Future<void> dispose() async {
    await _closeOpenBoxes();
    _openForUid = null;
  }

  // ─────────────────────────────── public API ───────────────────────────────
  static Future<List<CategoryModel>> getAllCategories() async {
    final uid = _requireUserOrNull();
    if (uid == null) return const <CategoryModel>[];

    await _ensureBoxes(uid);
    final box = Hive.box(_customBoxName(uid));
    return box.values
        .whereType<Map>()
        .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  static Future<void> saveCategory(String category) async {
    final name = category.trim();
    if (name.isEmpty || _systemCategories.contains(name)) return;

    final uid = _requireUserOrThrow();
    await _ensureBoxes(uid);

    // Local write (de-dup by name)
    final box = Hive.box(_customBoxName(uid));
    final exists = box.values.whereType<Map>().any((e) => e['name'] == name);
    if (!exists) {
      final model = CategoryModel(id: name, name: name);
      await box.add(model.toJson());
    }

    // Firestore mirror
    try {
      await _fs
          .collection('users')
          .doc(uid)
          .collection('categories')
          .doc(name)
          .set({'name': name}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Firestore saveCategory("$name") failed: $e');
    }
  }

  static Future<void> deleteCategory(String category) async {
    final name = category.trim();
    if (name.isEmpty || _systemCategories.contains(name)) return;

    final uid = _requireUserOrThrow();
    await _ensureBoxes(uid);

    // Local remove (null-safe lookup)
    final box = Hive.box(_customBoxName(uid));
    dynamic foundKey;
    for (final k in box.keys) {
      final v = box.get(k);
      if (v is Map && v['name'] == name) {
        foundKey = k;
        break;
      }
    }
    if (foundKey != null) {
      await box.delete(foundKey);
    }

    // Firestore delete
    try {
      await _fs
          .collection('users')
          .doc(uid)
          .collection('categories')
          .doc(name)
          .delete();
    } catch (e) {
      debugPrint('⚠️ Firestore deleteCategory("$name") failed: $e');
    }
  }

  /// Pulls categories from Firestore and replaces the local box with them.
  /// Also syncs hidden defaults from /users/{uid}/prefs/app.hiddenDefaultCategories.
  static Future<void> syncFromFirestore() async {
    final uid = _requireUserOrNull();
    if (uid == null) {
      debugPrint('⚠️ Cannot sync categories – no user signed in');
      return;
    }
    await _ensureBoxes(uid);

    try {
      // Categories
      final ref = _fs.collection('users').doc(uid).collection('categories');
      final snap = await ref.get();

      final box = Hive.box(_customBoxName(uid));
      await box.clear();

      for (final doc in snap.docs) {
        final name = doc.data()['name'];
        if (name is String && !_systemCategories.contains(name)) {
          await box.add(CategoryModel(id: name, name: name).toJson());
        }
      }

      // Hidden defaults (soft-deletes) — source of truth = Firestore
      await _syncHiddenDefaultsFromFirestore(uid);

      // Ensure seed defaults exist locally (even if not in Firestore)
      await _ensureSeedUserDefaultsLocal(uid);
    } catch (e) {
      debugPrint('⚠️ Failed to sync categories from Firestore: $e');
    }
  }

  // ─────────────────────── default visibility (soft delete) ────────────────
  /// Hide one of the seed defaults (Breakfast/Main/Dessert).
  /// Mirrors to Firestore under /users/{uid}/prefs/app.hiddenDefaultCategories.
  static Future<void> hideDefaultCategory(String category) async {
    final uid = _requireUserOrNull();
    if (uid == null) return;
    if (!_seedUserDefaults.contains(category)) return;

    await _ensureBoxes(uid);

    // Local (Hive)
    final box = Hive.box<String>(_hiddenDefaultBox(uid));
    await box.put(category, category);

    // Firestore mirror (append to array if not present)
    try {
      final doc = _fs
          .collection('users')
          .doc(uid)
          .collection('prefs')
          .doc('app');
      final snap = await doc.get();
      final current =
          (snap.data()?['hiddenDefaultCategories'] as List?)?.cast<String>() ??
          <String>[];
      if (!current.contains(category)) current.add(category);
      await doc.set({
        'hiddenDefaultCategories': current,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ FS hideDefaultCategory("$category") failed: $e');
    }
  }

  /// Unhide one of the seed defaults (Breakfast/Main/Dessert).
  /// Mirrors to Firestore under /users/{uid}/prefs/app.hiddenDefaultCategories.
  static Future<void> unhideDefaultCategory(String category) async {
    final uid = _requireUserOrNull();
    if (uid == null) return;

    await _ensureBoxes(uid);

    // Local (Hive)
    final box = Hive.box<String>(_hiddenDefaultBox(uid));
    await box.delete(category);

    // Firestore mirror (remove from array)
    try {
      final doc = _fs
          .collection('users')
          .doc(uid)
          .collection('prefs')
          .doc('app');
      final snap = await doc.get();
      final current =
          (snap.data()?['hiddenDefaultCategories'] as List?)?.cast<String>() ??
          <String>[];
      current.removeWhere((c) => c == category);
      await doc.set({
        'hiddenDefaultCategories': current,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ FS unhideDefaultCategory("$category") failed: $e');
    }
  }

  /// Get the list of hidden seed defaults. Tries Firestore first to keep
  /// multiple devices in sync; falls back to the local Hive cache if offline.
  static Future<List<String>> getHiddenDefaultCategories() async {
    final uid = _requireUserOrNull();
    if (uid == null) return const <String>[];

    await _ensureBoxes(uid);

    // Try Firestore first (preferred source)
    try {
      final doc = await _fs
          .collection('users')
          .doc(uid)
          .collection('prefs')
          .doc('app')
          .get();
      final remote =
          (doc.data()?['hiddenDefaultCategories'] as List?)?.cast<String>() ??
          <String>[];

      // Keep Hive in sync with remote
      final box = Hive.box<String>(_hiddenDefaultBox(uid));
      await box.clear();
      for (final c in remote) {
        await box.put(c, c);
      }
      return remote;
    } catch (_) {
      // Offline or first run: use Hive cache
      final box = Hive.box<String>(_hiddenDefaultBox(uid));
      return box.values.toList(growable: false);
    }
  }

  // ─────────────────────────────── cache management ─────────────────────────
  static Future<void> clearCache() async {
    final uid = _openForUid;
    if (uid == null) return;

    try {
      if (Hive.isBoxOpen(_customBoxName(uid))) {
        await Hive.box(_customBoxName(uid)).clear();
        debugPrint('🧹 Cleared ${_customBoxName(uid)}');
      }
      if (Hive.isBoxOpen(_hiddenDefaultBox(uid))) {
        await Hive.box<String>(_hiddenDefaultBox(uid)).clear();
        debugPrint('🧹 Cleared ${_hiddenDefaultBox(uid)}');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to clear category cache: $e');
    }
  }

  static Future<void> clearCacheForUser(String uid) async {
    final custom = _customBoxName(uid);
    final hidden = _hiddenDefaultBox(uid);

    try {
      if (Hive.isBoxOpen(custom)) {
        await Hive.box(custom).deleteFromDisk();
      } else if (await Hive.boxExists(custom)) {
        await Hive.deleteBoxFromDisk(custom);
      }

      if (Hive.isBoxOpen(hidden)) {
        await Hive.box<String>(hidden).deleteFromDisk();
      } else if (await Hive.boxExists(hidden)) {
        await Hive.deleteBoxFromDisk(hidden);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to clear category data for $uid: $e');
    }
  }

  // ─────────────────────────────── internals ────────────────────────────────
  static Future<void> _switchUser(String? nextUid) async {
    if (_openForUid == nextUid) return;

    // Close previous user boxes
    await _closeOpenBoxes();

    _openForUid = nextUid;

    if (nextUid == null) {
      if (kDebugMode) {
        debugPrint('📦 CategoryService: signed out – no boxes open');
      }
      return;
    }

    // Open boxes for the new user
    await _ensureBoxes(nextUid);

    // Legacy migration + seed defaults
    await _migrateLegacyFor(nextUid);

    // Seed defaults always present locally
    await _ensureSeedUserDefaultsLocal(nextUid);

    // Pull hidden defaults from Firestore into Hive for this user
    await _syncHiddenDefaultsFromFirestore(nextUid);
  }

  static Future<void> _closeOpenBoxes() async {
    final prev = _openForUid;
    if (prev == null) return;

    final prevCustom = _customBoxName(prev);
    final prevHidden = _hiddenDefaultBox(prev);

    try {
      if (Hive.isBoxOpen(prevCustom)) await Hive.box(prevCustom).close();
      if (Hive.isBoxOpen(prevHidden)) await Hive.box(prevHidden).close();
    } catch (e) {
      debugPrint('⚠️ Failed closing previous user category boxes: $e');
    }
  }

  static Future<void> _ensureBoxes(String uid) async {
    final custom = _customBoxName(uid);
    final hidden = _hiddenDefaultBox(uid);

    if (!Hive.isBoxOpen(custom)) {
      try {
        await Hive.openBox(custom);
        if (kDebugMode) debugPrint('📦 Opened box: $custom');
      } catch (e) {
        debugPrint('⚠️ Failed to open $custom: $e');
      }
    }
    if (!Hive.isBoxOpen(hidden)) {
      try {
        await Hive.openBox<String>(hidden);
        if (kDebugMode) debugPrint('📦 Opened box: $hidden');
      } catch (e) {
        debugPrint('⚠️ Failed to open $hidden: $e');
      }
    }
  }

  /// Migrate legacy String entries in the custom box → CategoryModel JSON
  static Future<void> _migrateLegacyFor(String uid) async {
    final box = Hive.box(_customBoxName(uid));
    final legacyKeys = box.keys.where((k) => box.get(k) is String).toList();
    for (final key in legacyKeys) {
      final name = box.get(key) as String;
      await box.put(key, CategoryModel(id: name, name: name).toJson());
      debugPrint('🔁 Migrated legacy category "$name"');
    }
  }

  /// Ensure the seed user categories exist locally (Breakfast/Main/Dessert).
  static Future<void> _ensureSeedUserDefaultsLocal(String uid) async {
    final box = Hive.box(_customBoxName(uid));
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

  /// Pull hidden defaults from Firestore into the Hive cache for this user.
  static Future<void> _syncHiddenDefaultsFromFirestore(String uid) async {
    try {
      final doc = await _fs
          .collection('users')
          .doc(uid)
          .collection('prefs')
          .doc('app')
          .get();
      final remote =
          (doc.data()?['hiddenDefaultCategories'] as List?)?.cast<String>() ??
          <String>[];

      final box = Hive.box<String>(_hiddenDefaultBox(uid));
      await box.clear();
      for (final c in remote) {
        if (_seedUserDefaults.contains(c)) {
          await box.put(c, c);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to sync hidden defaults from Firestore: $e');
    }
  }

  // ─────────────────────────────── guards ───────────────────────────────────
  static String? _requireUserOrNull() => _auth.currentUser?.uid;

  static String _requireUserOrThrow() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('❌ No logged in user — UID required.');
    }
    return uid;
  }
}
