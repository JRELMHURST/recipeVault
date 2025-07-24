import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class UserPreferencesService {
  static const String _boxName = 'userPrefs';
  static const String _keyViewMode = 'viewMode';
  static const String _keyVaultTutorialComplete = 'vaultTutorialComplete';
  static const String _keyBubblesShownOnce = 'hasShownBubblesOnce';
  static const List<String> _bubbleKeys = ['scan', 'viewToggle', 'longPress'];

  static late Box _box;

  // ──────────────────────────────────────────────────────────────────────────────
  /// 📦 Init
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Future<Box> getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// 🧩 View Mode
  static int getViewMode() => _box.get(_keyViewMode, defaultValue: 0) as int;

  static Future<void> setViewMode(int mode) async =>
      await _box.put(_keyViewMode, mode);

  // ──────────────────────────────────────────────────────────────────────────────
  /// 🧪 Vault Tutorial
  static Future<void> markVaultTutorialCompleted() async {
    await _box.put(_keyVaultTutorialComplete, true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'onboarding': {'vaultTutorialCompleted': true},
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to write onboarding to Firestore: $e');
    }
  }

  static Future<bool> hasCompletedVaultTutorial() async {
    final local =
        _box.get(_keyVaultTutorialComplete, defaultValue: false) as bool;
    if (local) return true;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final completed =
          doc.data()?['onboarding']?['vaultTutorialCompleted'] ?? false;

      if (completed == true) {
        final alreadySet =
            _box.get(_keyVaultTutorialComplete, defaultValue: false) as bool;
        if (!alreadySet) {
          await _box.put(_keyVaultTutorialComplete, true);
          if (kDebugMode) {
            print('📥 Caching vaultTutorialCompleted=true from Firestore');
          }
        }
      }
      return completed;
    } catch (e) {
      if (kDebugMode) print('🧨 Firestore onboarding check failed: $e');
      return false;
    }
  }

  static Future<void> resetVaultTutorial({bool localOnly = true}) async {
    await _box.delete(_keyVaultTutorialComplete);

    if (!localOnly) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'onboarding': {'vaultTutorialCompleted': FieldValue.delete()},
          }, SetOptions(merge: true));
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to delete onboarding from Firestore: $e');
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// 💬 Bubble Dismissals
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
        print('⚠️ Failed to write bubble "$key" to Firestore: $e');
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

      if (dismissed) await _box.put('bubbleDismissed_$key', true);
      return dismissed;
    } catch (e) {
      if (kDebugMode) print('🧨 Firestore bubble check failed for "$key": $e');
      return false;
    }
  }

  static Future<bool> shouldShowBubble(String key) async {
    final dismissed = await hasDismissedBubble(key);
    if (kDebugMode) print('👀 Bubble "$key" dismissed? $dismissed');
    return !dismissed;
  }

  static Future<void> resetBubbles({bool deleteRemote = false}) async {
    for (final key in _bubbleKeys) {
      await _box.delete('bubbleDismissed_$key');
    }

    if (deleteRemote) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final updates = {
            for (var key in _bubbleKeys)
              'onboarding.bubbleDismissals.$key': FieldValue.delete(),
          };
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set(updates, SetOptions(merge: true));
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to delete remote bubbles: $e');
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// 🧠 Bubble Trigger
  static Future<void> ensureBubbleFlagTriggeredIfEligible(String tier) async {
    final hasSeenTutorial =
        _box.get(_keyVaultTutorialComplete, defaultValue: false) as bool;
    if (kDebugMode) {
      print(
        '📊 Bubble trigger check: tier=$tier, hasSeenTutorial=$hasSeenTutorial',
      );
    }

    if (tier == 'free' && !hasSeenTutorial) {
      await resetBubbles();
      await _box.put(_keyBubblesShownOnce, true);

      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('analytics').add({
            'event': 'bubbles_triggered',
            'tier': tier,
            'timestamp': FieldValue.serverTimestamp(),
            'uid': uid,
          });
        }
      } catch (e) {
        if (kDebugMode) print('📉 Failed to log onboarding analytics: $e');
      }

      if (kDebugMode) {
        print('🆕 Bubbles triggered for free tier (tutorial not yet complete)');
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// 🌟 Bubble Tracking
  static Future<bool> get hasShownBubblesOnce async =>
      _box.get(_keyBubblesShownOnce, defaultValue: false) as bool;

  static Future<void> markBubblesShown() async =>
      await _box.put(_keyBubblesShownOnce, true);

  // ──────────────────────────────────────────────────────────────────────────────
  /// 🧪 Developer Utilities
  static Future<void> clearAll() async => await _box.clear();

  static dynamic get(String key) => _box.get(key);

  static Future<void> set(String key, dynamic value) async =>
      await _box.put(key, value);

  static Future<void> setBool(String key, bool value) async =>
      await _box.put(key, value);
}
