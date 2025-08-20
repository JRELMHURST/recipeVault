// lib/data/services/user_preference_service.dart
// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 📦 Internal-to-persistence view modes (renamed to avoid clashes)
enum PrefsViewMode { list, grid, compact }

extension PrefsViewModeX on PrefsViewMode {
  String get label => switch (this) {
    PrefsViewMode.list => 'List',
    PrefsViewMode.grid => 'Grid',
    PrefsViewMode.compact => 'Compact',
  };

  String get iconAsset => switch (this) {
    PrefsViewMode.list => 'assets/icons/view_list.png',
    PrefsViewMode.grid => 'assets/icons/view_grid.png',
    PrefsViewMode.compact => 'assets/icons/view_compact.png',
  };
}

class UserPreferencesService {
  // ─────────────────────────────── keys ───────────────────────────────
  static const String _keyViewMode = 'viewMode';
  static const String _keyAiUsage = 'aiUsage';
  static const String _keyTranslationUsage = 'translationUsage';

  // ─────────────────────────────── hive state ─────────────────────────
  static String? _activeUid;
  static Box? _box;

  static String? _currentUid() => FirebaseAuth.instance.currentUser?.uid;
  static String _boxNameFor(String uid) => 'userPrefs_$uid';

  static bool get isBoxOpen => _box?.isOpen == true;

  // ─────────────────────────────── lifecycle ──────────────────────────

  /// Call at app start. Safe to call before sign-in; no-op until a UID exists.
  static Future<void> init() async {
    await _ensureBoxForCurrentUser();
  }

  /// Called by app_bootstrap on auth state changes.
  static Future<void> onAuthChanged(String? uid) async {
    // If null → signed out: close any open box.
    if (uid == null) {
      await close();
      if (kDebugMode) {
        debugPrint('ℹ️ UserPreferencesService: signed out — box closed.');
      }
      return;
    }
    // Switch to the new user's box if needed.
    await _openBoxFor(uid);
  }

  /// Ensures the per-user box is opened for the *current* Firebase UID.
  /// If not signed in, this is a no-op.
  static Future<void> _ensureBoxForCurrentUser() async {
    final uid = _currentUid();
    if (uid == null) {
      await close();
      if (kDebugMode) debugPrint('ℹ️ No UID yet — prefs box not opened.');
      return;
    }
    await _openBoxFor(uid);
  }

  static Future<void> _openBoxFor(String uid) async {
    if (_activeUid == uid && _box?.isOpen == true) return;

    // Close previous user’s box if open.
    if (_box?.isOpen == true) {
      try {
        await _box!.close();
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Failed closing previous prefs box: $e');
      } finally {
        _box = null;
        _activeUid = null;
      }
    }

    final name = _boxNameFor(uid);
    try {
      _box = await Hive.openBox(name);
      _activeUid = uid;
      if (kDebugMode) debugPrint('📦 Hive prefs box opened: $name');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to open prefs box $name: $e');
    }
  }

  /// Returns an open box or `null` when not signed in (no throw).
  static Future<Box?> _ensureBox() async {
    await _ensureBoxForCurrentUser();
    return (_box?.isOpen == true) ? _box : null;
  }

  static Future<void> close() async {
    try {
      if (_box?.isOpen == true) await _box!.close();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error closing prefs box: $e');
    } finally {
      _box = null;
      _activeUid = null;
    }
  }

  // ─────────────────────────────── view mode ──────────────────────────

  static Future<void> saveViewMode(PrefsViewMode mode) async {
    final box = await _ensureBox();
    if (box == null) return; // not signed in yet
    await box.put(_keyViewMode, mode.index);
    if (kDebugMode) debugPrint('📂 Saved view mode: ${mode.name}');
  }

  static Future<PrefsViewMode> getSavedViewMode() async {
    final box = await _ensureBox();
    final index = box?.get(_keyViewMode) as int?;
    final mode =
        (index != null && index >= 0 && index < PrefsViewMode.values.length)
        ? PrefsViewMode.values[index]
        : PrefsViewMode.grid;
    if (kDebugMode) debugPrint('📅 Loaded view mode: ${mode.name}');
    return mode;
  }

  // ─────────────────────────── usage counters ─────────────────────────

  static Future<void> setCachedUsage({int? ai, int? translations}) async {
    final box = await _ensureBox();
    if (box == null) return;
    if (ai != null) await box.put(_keyAiUsage, ai);
    if (translations != null) await box.put(_keyTranslationUsage, translations);
    if (kDebugMode) {
      debugPrint('📂 Cached usage: AI=$ai, Translations=$translations');
    }
  }

  static Future<int> getCachedAiUsage() async {
    final box = await _ensureBox();
    return box?.get(_keyAiUsage, defaultValue: 0) as int? ?? 0;
  }

  static Future<int> getCachedTranslationUsage() async {
    final box = await _ensureBox();
    return box?.get(_keyTranslationUsage, defaultValue: 0) as int? ?? 0;
  }

  // ───────────────────────────── misc get/set ─────────────────────────

  static dynamic get(String key) =>
      (_box?.isOpen == true) ? _box!.get(key) : null;

  static Future<void> set(String key, dynamic value) async {
    final box = await _ensureBox();
    if (box == null) return;
    await box.put(key, value);
  }

  static Future<void> setBool(String key, bool value) async {
    final box = await _ensureBox();
    if (box == null) return;
    await box.put(key, value);
  }

  // ─────────────── clearing helpers (logout / delete account) ───────────────

  /// Clears *all* local preference data for the specified uid.
  static Future<void> clearAllUserData(String uid) async {
    await deleteLocalDataForUser(uid);
    await clearAllPreferences(uid);
    if (kDebugMode) debugPrint('🧼 All local user prefs cleared for $uid');
  }

  static Future<void> deleteLocalDataForUser(String uid) async {
    final name = _boxNameFor(uid);
    await _closeAndDeleteBox(name);
  }

  /// Legacy keys that might have been written to SharedPreferences; clean them up.
  static Future<void> clearAllPreferences(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = <String>[
        'viewMode_$uid',
        'hasShownBubblesOnce_$uid',
        'vaultTutorialComplete_$uid',
        'isNewUser_$uid',
      ];
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      if (kDebugMode) debugPrint('🧹 SharedPreferences cleared for $uid');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to clear SharedPreferences for $uid: $e');
      }
    }
  }

  static Future<void> _closeAndDeleteBox(String name) async {
    try {
      if (Hive.isBoxOpen(name)) {
        final box = Hive.box(name);
        if (box.isOpen) await box.close();
      }
      await Hive.deleteBoxFromDisk(name);
      if (kDebugMode) debugPrint('📦 Cleared Hive box "$name"');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Hive box deletion failed for "$name": $e');
    }
  }
}
