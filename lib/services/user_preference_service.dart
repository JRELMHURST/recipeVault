import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/core/feature_flags.dart';

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
  static const String _keyViewMode = 'viewMode';
  static const String _keyVaultTutorialComplete = 'vaultTutorialComplete';
  static const String _keyBubblesShownOnce = 'hasShownBubblesOnce';
  static const String _keyAiUsage = 'aiUsage';
  static const String _keyTranslationUsage = 'translationUsage';

  /// Order matters only for `maybeMarkTutorialCompleted`.
  static const List<String> _bubbleKeys = ['viewToggle', 'longPress', 'scan'];

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  static String get _boxName => 'userPrefs_$_uid';

  static Box? _box;
  static String? _boxForUid;

  static bool get isBoxOpen => _box?.isOpen == true;
  static Box? get _safeBox => _box?.isOpen == true ? _box : null;

  // ── Lifecycle / user switching ─────────────────────────────────────────────

  static Future<void> init() async {
    if (_uid == 'unknown') {
      if (kDebugMode) {
        debugPrint('🟡 UserPreferencesService.init() skipped – no user');
      }
      return;
    }
    await _ensureBoxForCurrentUser();
  }

  static Future<void> _ensureBoxForCurrentUser() async {
    if (_box?.isOpen == true && _boxForUid != _uid) {
      try {
        await _box!.close();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Failed closing previous prefs box: $e');
        }
      }
      _box = null;
      _boxForUid = null;
    }

    if (!Hive.isBoxOpen(_boxName)) {
      try {
        _box = await Hive.openBox(_boxName);
        _boxForUid = _uid;
        if (kDebugMode) debugPrint('📦 Hive prefs box opened: $_boxName');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Failed to open prefs box $_boxName: $e');
        }
      }
    } else {
      _box = Hive.box(_boxName);
      _boxForUid = _uid;
      if (kDebugMode) debugPrint('📦 Hive prefs box reused: $_boxName');
    }
  }

  static Future<Box?> _ensureBox() async {
    if (_box?.isOpen == true && _boxForUid == _uid) return _box;
    await _ensureBoxForCurrentUser();
    return _safeBox;
  }

  static Future<void> close() async {
    try {
      if (_box?.isOpen == true) await _box!.close();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error closing prefs box $_boxName: $e');
      }
    }
    _box = null;
    _boxForUid = null;
  }

  // ── View mode ──────────────────────────────────────────────────────────────

  static Future<void> saveViewMode(PrefsViewMode mode) async {
    final box = await _ensureBox();
    if (box != null) {
      await box.put(_keyViewMode, mode.index);
      if (kDebugMode) debugPrint('📂 Saved view mode: ${mode.name}');
    }
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

  // ── Onboarding / bubbles ──────────────────────────────────────────────────

  static Future<void> markVaultTutorialCompleted() async {
    final box = await _ensureBox();
    if (box != null) await box.put(_keyVaultTutorialComplete, true);
  }

  static Future<void> maybeMarkTutorialCompleted() async {
    final results = await Future.wait(_bubbleKeys.map(hasDismissedBubble));
    if (results.every((b) => b)) {
      await markVaultTutorialCompleted();
    }
  }

  static Future<bool> hasCompletedVaultTutorial() async {
    final box = await _ensureBox();
    return box?.get(_keyVaultTutorialComplete, defaultValue: false) as bool? ??
        false;
  }

  static Future<void> markBubbleDismissed(String key) async {
    final box = await _ensureBox();
    if (box != null) {
      await box.put('bubbleDismissed_$key', true);
      await maybeMarkTutorialCompleted();
    }
  }

  static Future<bool> hasDismissedBubble(String key) async {
    final box = await _ensureBox();
    return box?.get('bubbleDismissed_$key', defaultValue: false) as bool? ??
        false;
  }

  static Future<bool> shouldShowBubble(String key) async {
    final dismissed = await hasDismissedBubble(key);
    if (kDebugMode) debugPrint('👀 Bubble "$key" dismissed? $dismissed');
    return !dismissed;
  }

  static Future<void> resetBubbles() async {
    final box = await _ensureBox();
    if (box != null) {
      for (final key in _bubbleKeys) {
        await box.delete('bubbleDismissed_$key');
      }
    }
  }

  /// Prepare onboarding bubble flags (feature-flag aware).
  static Future<void> ensureBubbleFlagTriggeredIfEligible() async {
    final box = await _ensureBox();
    if (box == null) return;

    if (!kOnboardingBubblesEnabled) {
      await box.put(_keyBubblesShownOnce, true);
      await box.put(_keyVaultTutorialComplete, true);
      if (kDebugMode) {
        debugPrint(
          '🧪 Onboarding disabled via feature flag – marking as completed.',
        );
      }
      return;
    }

    final hasShownBubblesOnce =
        box.get(_keyBubblesShownOnce, defaultValue: false) as bool? ?? false;
    final tutorialComplete =
        box.get(_keyVaultTutorialComplete, defaultValue: false) as bool? ??
        false;

    if (kDebugMode) {
      debugPrint(
        '📊 Bubble trigger check: shownOnce=$hasShownBubblesOnce, completed=$tutorialComplete',
      );
    }

    if (!hasShownBubblesOnce && !tutorialComplete) {
      await resetBubbles();
      if (kDebugMode) debugPrint('🌟 Bubbles prepared for first-time user');
    }
  }

  static Future<bool> get hasShownBubblesOnce async {
    final box = await _ensureBox();
    return box?.get(_keyBubblesShownOnce, defaultValue: false) as bool? ??
        false;
  }

  static Future<void> markBubblesShown() async {
    final box = await _ensureBox();
    if (box != null) await box.put(_keyBubblesShownOnce, true);
  }

  static Future<void> markAsNewUser() async {
    final box = await _ensureBox();
    if (box != null) {
      await box.delete(_keyVaultTutorialComplete);
      await box.delete(_keyBubblesShownOnce);
      for (final key in _bubbleKeys) {
        await box.delete('bubbleDismissed_$key');
      }
      if (kDebugMode) debugPrint('🎯 Onboarding flags cleared (new user mode)');
    }
  }

  static Future<void> waitForBubbleFlags() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // ── Usage counters (local cache) ───────────────────────────────────────────

  static Future<void> setCachedUsage({int? ai, int? translations}) async {
    final box = await _ensureBox();
    if (box != null) {
      if (ai != null) await box.put(_keyAiUsage, ai);
      if (translations != null) {
        await box.put(_keyTranslationUsage, translations);
      }
      if (kDebugMode) {
        debugPrint('📂 Cached usage: AI=$ai, Translations=$translations');
      }
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

  // ── Misc get/set helpers ──────────────────────────────────────────────────

  static dynamic get(String key) => _safeBox?.get(key);

  static Future<void> set(String key, dynamic value) async {
    final box = await _ensureBox();
    if (box != null) await box.put(key, value);
  }

  static Future<void> setBool(String key, bool value) async {
    final box = await _ensureBox();
    if (box != null) await box.put(key, value);
  }

  // ── Clearing helpers (logout / delete account) ─────────────────────────────

  static Future<void> clearAllUserData(String uid) async {
    await deleteLocalDataForUser(uid);
    await clearAllPreferences(uid);
    if (kDebugMode) debugPrint('🧼 All local user prefs cleared for $uid');
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
      if (kDebugMode) {
        debugPrint('⚠️ Hive box deletion failed for "$name": $e');
      }
    }
  }
}
