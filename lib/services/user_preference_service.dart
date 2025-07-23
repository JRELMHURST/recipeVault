import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class UserPreferencesService {
  static const String _boxName = 'userPrefs';
  static const String _keyViewMode = 'viewMode';
  static const String _keyVaultTutorialComplete = 'vaultTutorialComplete';
  static const String _keyIsNewUser = 'isNewUser';

  static const List<String> _bubbleKeys = ['scan', 'viewToggle', 'longPress'];

  static late Box _box;

  /// Opens the Hive box for user preferences (called in main.dart)
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// 🧩 View Mode
  static int getViewMode() {
    return _box.get(_keyViewMode, defaultValue: 0) as int;
  }

  static Future<void> setViewMode(int mode) async {
    await _box.put(_keyViewMode, mode);
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// 🧪 Vault Tutorial
  static Future<void> markVaultTutorialCompleted() async {
    await _box.put(_keyVaultTutorialComplete, true);
    await _box.put(_keyIsNewUser, false);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'onboarding': {'vaultTutorialCompleted': true},
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to write onboarding to Firestore: $e');
      }
    }
  }

  static Future<bool> hasCompletedVaultTutorial() async {
    final local =
        _box.get(_keyVaultTutorialComplete, defaultValue: false) as bool;
    if (local == true) return true;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final completed =
          doc.data()?['onboarding']?['vaultTutorialCompleted'] ?? false;

      if (completed) {
        await _box.put(_keyVaultTutorialComplete, true); // Cache locally
      }

      return completed;
    } catch (e) {
      if (kDebugMode) {
        print('🧨 Firestore onboarding check failed: $e');
      }
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// 🆕 New User Flag
  static Future<void> setNewUserFlag() async {
    await _box.put(_keyIsNewUser, true);
  }

  static bool get isNewUser =>
      _box.get(_keyIsNewUser, defaultValue: false) as bool;

  static Future<void> clearNewUserFlag() async {
    await _box.put(_keyIsNewUser, false);
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// 💬 Bubble Dismissals (Generalised) with Firestore sync
  static Future<void> markBubbleDismissed(String key) async {
    await _box.put('bubbleDismissed_$key', true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'onboarding': {
            'bubbleDismissals': {key: true},
          },
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to write bubble "$key" dismissal to Firestore: $e');
      }
    }
  }

  static Future<bool> hasDismissedBubble(String key) async {
    final local = _box.get('bubbleDismissed_$key', defaultValue: false) as bool;
    if (local) return true;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final dismissed =
          doc.data()?['onboarding']?['bubbleDismissals']?[key] ?? false;

      if (dismissed) {
        await _box.put('bubbleDismissed_$key', true); // Cache it
      }

      return dismissed;
    } catch (e) {
      if (kDebugMode) {
        print('🧨 Firestore bubble dismissal check failed for "$key": $e');
      }
      return false;
    }
  }

  static Future<bool> shouldShowBubble(String key) async {
    final dismissed = await hasDismissedBubble(key);
    if (kDebugMode) print('👀 Bubble "$key" dismissed? $dismissed');
    return !dismissed;
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// 🧪 Developer/Test Utilities
  static Future<void> resetVaultTutorial() async {
    await _box.delete(_keyVaultTutorialComplete);
    await _box.put(_keyIsNewUser, true);
  }

  static Future<void> resetBubbles() async {
    for (final key in _bubbleKeys) {
      await _box.delete('bubbleDismissed_$key');
    }
  }

  static Future<void> clearAll() async {
    await _box.clear();
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// 🛠️ Advanced Accessors
  static dynamic get(String key) => _box.get(key);

  static Future<void> set(String key, dynamic value) async {
    await _box.put(key, value);
  }
}
