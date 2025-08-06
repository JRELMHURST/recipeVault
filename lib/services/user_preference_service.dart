import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🛍 User-facing view modes
enum ViewMode { list, grid, compact }

extension ViewModeExtension on ViewMode {
  String get label {
    switch (this) {
      case ViewMode.list:
        return 'List';
      case ViewMode.grid:
        return 'Grid';
      case ViewMode.compact:
        return 'Compact';
    }
  }

  String get iconAsset {
    switch (this) {
      case ViewMode.list:
        return 'assets/icons/view_list.png';
      case ViewMode.grid:
        return 'assets/icons/view_grid.png';
      case ViewMode.compact:
        return 'assets/icons/view_compact.png';
    }
  }
}

class UserPreferencesService {
  static const String _keyViewMode = 'viewMode';
  static const String _keyVaultTutorialComplete = 'vaultTutorialComplete';
  static const String _keyBubblesShownOnce = 'hasShownBubblesOnce';
  static const String _keyAiUsage = 'aiUsage';
  static const String _keyTranslationUsage = 'translationUsage';
  static const List<String> _bubbleKeys = ['scan', 'viewToggle', 'longPress'];

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  static String get _boxName => 'userPrefs_$_uid';

  static bool get isBoxOpen => Hive.isBoxOpen(_boxName);

  static Box? get _safeBox {
    if (!Hive.isBoxOpen(_boxName)) return null;
    try {
      return Hive.box(_boxName);
    } catch (e) {
      debugPrint('⚠️ _safeBox access failed: $e');
      return null;
    }
  }

  static Future<void> init() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (kDebugMode) {
        print('🟡 Skipping UserPreferencesService.init() – no user signed in');
      }
      return;
    }

    if (Hive.isBoxOpen(_boxName)) {
      if (kDebugMode) print('📦 Hive box reused: $_boxName');
    } else {
      if (kDebugMode) print('📦 Hive box opened: $_boxName');
    }
  }

  static Future<void> saveViewMode(ViewMode mode) async {
    final box = _safeBox;
    if (box != null) {
      await box.put(_keyViewMode, mode.index);
      if (kDebugMode) print('📂 Saved view mode: ${mode.name}');
    }
  }

  static Future<ViewMode> getSavedViewMode() async {
    final box = _safeBox;
    final index = box?.get(_keyViewMode) as int?;
    final mode = index != null && index >= 0 && index < ViewMode.values.length
        ? ViewMode.values[index]
        : ViewMode.grid;
    if (kDebugMode) print('📅 Loaded view mode: ${mode.name}');
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
      if (kDebugMode) print('🌟 Bubbles triggered for free tier (first time)');
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

  static Future<void> markUserAsNew() async {
    final box = _safeBox;
    if (box != null) {
      await box.put('isNewUser', true);
      if (kDebugMode) print('🔟 markUserAsNew → Hive only');
    }
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

  static Future<void> deleteLocalDataForUser(String uid) async {
    final name = 'userPrefs_$uid';
    await _closeAndDeleteBox(name);
  }

  static Future<void> clearAllPreferences(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = [
        'viewMode_$uid',
        'hasShownBubblesOnce_$uid',
        'vaultTutorialComplete_$uid',
        'isNewUser_$uid',
      ];
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      if (kDebugMode) print('🧹 SharedPreferences cleared for $uid');
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to clear SharedPreferences for $uid: $e');
      }
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

  static Future<void> setCachedUsage({int? ai, int? translations}) async {
    final box = _safeBox;
    if (box != null) {
      if (ai != null) await box.put(_keyAiUsage, ai);
      if (translations != null) {
        await box.put(_keyTranslationUsage, translations);
      }
      if (kDebugMode) {
        print('📂 Cached usage: AI=$ai, Translations=$translations');
      }
    }
  }

  static Future<int> getCachedAiUsage() async {
    final box = _safeBox;
    return box?.get(_keyAiUsage, defaultValue: 0) as int? ?? 0;
  }

  static Future<int> getCachedTranslationUsage() async {
    final box = _safeBox;
    return box?.get(_keyTranslationUsage, defaultValue: 0) as int? ?? 0;
  }

  static Future<void> clearAllUserData(String uid) async {
    await deleteLocalDataForUser(uid);
    await clearAllPreferences(uid);
    if (kDebugMode) print('🧼 All local user data cleared for $uid');
  }

  /// 🔒 Internal: close and delete a Hive box
  static Future<void> _closeAndDeleteBox(String name) async {
    try {
      if (Hive.isBoxOpen(name)) {
        final box = Hive.box(name);
        if (box.isOpen) await box.close();
      }
      await Hive.deleteBoxFromDisk(name);
      if (kDebugMode) print('📦 Cleared Hive box "$name"');
    } catch (e) {
      if (kDebugMode) print('⚠️ Hive box deletion failed for "$name": $e');
    }
  }
}
