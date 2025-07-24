import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:recipe_vault/services/view_mode.dart';

class UserPreferencesService {
  static const String _keyViewMode = 'viewMode';
  static const String _keyVaultTutorialComplete = 'vaultTutorialComplete';
  static const String _keyBubblesShownOnce = 'hasShownBubblesOnce';
  static const List<String> _bubbleKeys = ['scan', 'viewToggle', 'longPress'];

  static late Box _box;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  static String get _boxName => 'userPrefs_$_uid';

  static Box? get _safeBox =>
      (_box.isOpen && Hive.isBoxOpen(_box.name)) ? _box : null;

  static Future<void> init() async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception(
        '❌ Cannot initialise UserPreferencesService – no signed-in user',
      );
    }

    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
      if (kDebugMode) print('📦 Hive box reused: $_boxName');
    } else {
      _box = await Hive.openBox(_boxName);
      if (kDebugMode) print('📦 Hive box opened: $_boxName');
    }
  }

  static Future<void> saveViewMode(ViewMode mode) async {
    final box = _safeBox;
    if (box != null) {
      await box.put(_keyViewMode, mode.index);
      if (kDebugMode) print('💾 Saved view mode: ${mode.name}');
    }
  }

  static Future<ViewMode> getSavedViewMode() async {
    final box = _safeBox;
    final index =
        box?.get(_keyViewMode, defaultValue: ViewMode.grid.index) as int? ?? 0;
    final mode = ViewMode.values[index];
    if (kDebugMode) print('📥 Loaded view mode: ${mode.name}');
    return mode;
  }

  static Future<void> markVaultTutorialCompleted() async {
    final box = _safeBox;
    if (box != null) await box.put(_keyVaultTutorialComplete, true);
  }

  static Future<void> maybeMarkTutorialCompleted() async {
    final results = await Future.wait(_bubbleKeys.map(hasDismissedBubble));
    if (results.every((b) => b)) {
      await markVaultTutorialCompleted();
    }
  }

  static Future<bool> hasCompletedVaultTutorial() async {
    final box = _safeBox;
    return box?.get(_keyVaultTutorialComplete, defaultValue: false) as bool? ??
        false;
  }

  static Future<void> markBubbleDismissed(String key) async {
    final box = _safeBox;
    if (box != null) {
      await box.put('bubbleDismissed_$key', true);
      await maybeMarkTutorialCompleted();
    }
  }

  static Future<bool> hasDismissedBubble(String key) async {
    final box = _safeBox;
    return box?.get('bubbleDismissed_$key', defaultValue: false) as bool? ??
        false;
  }

  static Future<bool> shouldShowBubble(String key) async {
    final dismissed = await hasDismissedBubble(key);
    if (kDebugMode) print('👀 Bubble "$key" dismissed? $dismissed');
    return !dismissed;
  }

  static Future<void> resetBubbles() async {
    final box = _safeBox;
    if (box != null) {
      for (final key in _bubbleKeys) {
        await box.delete('bubbleDismissed_$key');
      }
    }
  }

  static Future<void> ensureBubbleFlagTriggeredIfEligible(String tier) async {
    final box = _safeBox;
    final hasShownBubblesOnce =
        box?.get(_keyBubblesShownOnce, defaultValue: false) as bool? ?? false;
    final tutorialComplete =
        box?.get(_keyVaultTutorialComplete, defaultValue: false) as bool? ??
        false;

    if (kDebugMode) {
      print(
        '📊 Bubble trigger check: tier=$tier, bubblesShownOnce=$hasShownBubblesOnce, vaultTutorialCompleted=$tutorialComplete',
      );
    }

    if (tier == 'free' && !hasShownBubblesOnce) {
      await resetBubbles();
      if (box != null) await box.put(_keyBubblesShownOnce, true);
      if (kDebugMode) print('🆕 Bubbles triggered for free tier (first time)');
    }
  }

  static Future<bool> get hasShownBubblesOnce async {
    final box = _safeBox;
    return box?.get(_keyBubblesShownOnce, defaultValue: false) as bool? ??
        false;
  }

  static Future<void> markBubblesShown() async {
    final box = _safeBox;
    if (box != null) await box.put(_keyBubblesShownOnce, true);
  }

  static Future<void> markAsNewUser() async {
    final box = _safeBox;
    if (box != null) {
      await box.delete(_keyVaultTutorialComplete);
      await box.delete(_keyBubblesShownOnce);
      for (final key in _bubbleKeys) {
        await box.delete('bubbleDismissed_$key');
      }
      if (kDebugMode) {
        print('🎯 User marked as new → all onboarding flags cleared');
      }
    }
  }

  /// 🧹 Fully clear the box from disk (used on account deletion)
  static Future<void> deleteLocalDataForUser(String uid) async {
    final name = 'userPrefs_$uid';
    try {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).close();
      }
      await Hive.deleteBoxFromDisk(name);
      if (kDebugMode) print('🧼 Hive box "$name" closed and deleted from disk');
    } catch (e) {
      if (kDebugMode) print('⚠️ Hive box deletion failed for "$name": $e');
    }
  }

  static dynamic get(String key) => _safeBox?.get(key);

  static Future<void> set(String key, dynamic value) async {
    final box = _safeBox;
    if (box != null) await box.put(key, value);
  }

  static Future<void> setBool(String key, bool value) async {
    final box = _safeBox;
    if (box != null) await box.put(key, value);
  }

  static Future<void> waitForBubbleFlags() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  static Future<void> markUserAsNew() async {
    final box = _safeBox;
    if (box != null) {
      await box.put('isNewUser', true);
      if (kDebugMode) print('🆕 markUserAsNew → Hive only');
    }
  }
}
