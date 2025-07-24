import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:recipe_vault/services/view_mode.dart';

class UserPreferencesService {
  static const String _boxPrefix = 'userPrefs';
  static const String _keyViewMode = 'viewMode';
  static const String _keyVaultTutorialComplete = 'vaultTutorialComplete';
  static const String _keyBubblesShownOnce = 'hasShownBubblesOnce';
  static const List<String> _bubbleKeys = ['scan', 'viewToggle', 'longPress'];

  static late Box _box;

  static String get _boxName {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final name = '${_boxPrefix}_$uid';
    if (kDebugMode) print('📦 Box name resolved: $name');
    return name;
  }

  static Future<void> init() async {
    if (Hive.isBoxOpen('userPrefs_guest') &&
        FirebaseAuth.instance.currentUser != null) {
      await Hive.box('userPrefs_guest').close();
      if (kDebugMode) print('🧹 Closed guest box');
    }

    final name = _boxName;

    if (Hive.isBoxOpen(name)) {
      _box = Hive.box(name);
      if (kDebugMode) print('📦 Hive box reused: $name');
    } else {
      _box = await Hive.openBox(name);
      if (kDebugMode) print('📦 Hive box opened: $name');
    }

    if (kDebugMode) {
      print('👤 Firebase UID: ${FirebaseAuth.instance.currentUser?.uid}');
    }
  }

  static Future<Box> getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
      if (kDebugMode) print('📦 Hive box lazily opened: $_boxName');
    }
    return _box;
  }

  static Future<void> saveViewMode(ViewMode mode) async {
    await _box.put(_keyViewMode, mode.index);
    if (kDebugMode) print('💾 Saved view mode: ${mode.name}');
  }

  static Future<ViewMode> getSavedViewMode() async {
    final index =
        _box.get(_keyViewMode, defaultValue: ViewMode.list.index) as int;
    final mode = ViewMode.values[index];
    if (kDebugMode) print('📥 Loaded view mode: ${mode.name}');
    return mode;
  }

  static Future<int> getViewMode() async {
    return _box.get(_keyViewMode, defaultValue: 0) as int;
  }

  static Future<void> setViewMode(int index) async {
    await _box.put(_keyViewMode, index);
  }

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

  static Future<void> maybeMarkTutorialCompleted() async {
    final results = await Future.wait(_bubbleKeys.map(hasDismissedBubble));
    if (results.every((b) => b)) {
      await markVaultTutorialCompleted();
    }
  }

  static Future<bool> hasCompletedVaultTutorial() async {
    final local =
        _box.get(_keyVaultTutorialComplete, defaultValue: false) as bool;
    return local;
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

  static Future<void> markBubbleDismissed(String key) async {
    await _box.put('bubbleDismissed_$key', true);
    await maybeMarkTutorialCompleted();
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
    return local;
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

  static Future<void> ensureBubbleFlagTriggeredIfEligible(String tier) async {
    final hasShownBubblesOnce =
        _box.get(_keyBubblesShownOnce, defaultValue: false) as bool;
    final tutorialComplete =
        _box.get(_keyVaultTutorialComplete, defaultValue: false) as bool;

    if (kDebugMode) {
      print(
        '📊 Bubble trigger check: tier=$tier, bubblesShownOnce=$hasShownBubblesOnce, vaultTutorialCompleted=$tutorialComplete',
      );
    }

    if (tier == 'free' && !hasShownBubblesOnce) {
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
        print('🆕 Bubbles triggered for free tier (first time)');
      }
    }
  }

  static Future<bool> get hasShownBubblesOnce async =>
      _box.get(_keyBubblesShownOnce, defaultValue: false) as bool;

  static Future<void> markBubblesShown() async =>
      await _box.put(_keyBubblesShownOnce, true);

  static Future<void> clearAll() async => await _box.clear();

  static dynamic get(String key) => _box.get(key);

  static Future<void> set(String key, dynamic value) async =>
      await _box.put(key, value);

  static Future<void> setBool(String key, bool value) async =>
      await _box.put(key, value);

  static Future<void> waitForBubbleFlags() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}
