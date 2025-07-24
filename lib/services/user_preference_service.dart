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

  static Future<void> init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception(
        '❌ Cannot initialise UserPreferencesService – no signed-in user',
      );
    }

    final boxName = 'userPrefs_$uid';
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box(boxName);
      if (kDebugMode) print('📦 Hive box reused: $boxName');
    } else {
      _box = await Hive.openBox(boxName);
      if (kDebugMode) print('📦 Hive box opened: $boxName');
    }
  }

  static Future<void> saveViewMode(ViewMode mode) async {
    await _box.put(_keyViewMode, mode.index);
    if (kDebugMode) print('💾 Saved view mode: ${mode.name}');
  }

  static Future<ViewMode> getSavedViewMode() async {
    final index =
        _box.get(_keyViewMode, defaultValue: ViewMode.grid.index) as int;
    final mode = ViewMode.values[index];
    if (kDebugMode) print('📥 Loaded view mode: ${mode.name}');
    return mode;
  }

  static Future<void> markVaultTutorialCompleted() async {
    await _box.put(_keyVaultTutorialComplete, true);
  }

  static Future<void> maybeMarkTutorialCompleted() async {
    final results = await Future.wait(_bubbleKeys.map(hasDismissedBubble));
    if (results.every((b) => b)) {
      await markVaultTutorialCompleted();
    }
  }

  static Future<bool> hasCompletedVaultTutorial() async {
    return _box.get(_keyVaultTutorialComplete, defaultValue: false) as bool;
  }

  static Future<void> markBubbleDismissed(String key) async {
    await _box.put('bubbleDismissed_$key', true);
    await maybeMarkTutorialCompleted();
  }

  static Future<bool> hasDismissedBubble(String key) async {
    return _box.get('bubbleDismissed_$key', defaultValue: false) as bool;
  }

  static Future<bool> shouldShowBubble(String key) async {
    final dismissed = await hasDismissedBubble(key);
    if (kDebugMode) print('👀 Bubble "$key" dismissed? $dismissed');
    return !dismissed;
  }

  static Future<void> resetBubbles() async {
    for (final key in _bubbleKeys) {
      await _box.delete('bubbleDismissed_$key');
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
      if (kDebugMode) print('🆕 Bubbles triggered for free tier (first time)');
    }
  }

  static Future<bool> get hasShownBubblesOnce async =>
      _box.get(_keyBubblesShownOnce, defaultValue: false) as bool;

  static Future<void> markBubblesShown() async =>
      await _box.put(_keyBubblesShownOnce, true);

  static Future<void> markAsNewUser() async {
    await _box.delete(_keyVaultTutorialComplete);
    await _box.delete(_keyBubblesShownOnce);
    for (final key in _bubbleKeys) {
      await _box.delete('bubbleDismissed_$key');
    }
    if (kDebugMode) {
      print('🎯 User marked as new → all onboarding flags cleared');
    }
  }

  static Future<void> clearAll() async {
    final boxName = _box.name;
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
      await Hive.deleteBoxFromDisk(boxName);
      if (kDebugMode) {
        print('🧼 Hive box "$boxName" closed and deleted from disk');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Hive box deletion failed: $e');
    }
  }

  static dynamic get(String key) => _box.get(key);

  static Future<void> set(String key, dynamic value) async =>
      await _box.put(key, value);

  static Future<void> setBool(String key, bool value) async =>
      await _box.put(key, value);

  static Future<void> waitForBubbleFlags() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  static Future<void> markUserAsNew() async {
    await _box.put('isNewUser', true);
    if (kDebugMode) print('🆕 markUserAsNew → Hive only');
  }
}
