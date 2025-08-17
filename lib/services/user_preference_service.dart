import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/core/feature_flags.dart'; // ⬅️ feature flags

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

  /// Order matters only for `maybeMarkTutorialCompleted`.
  static const List<String> _bubbleKeys = ['viewToggle', 'longPress', 'scan'];

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  static String get _boxName => 'userPrefs_$_uid';

  static Box? _box;
  static String? _boxForUid;

  static bool get isBoxOpen => _box?.isOpen == true;

  static Box? get _safeBox => _box?.isOpen == true ? _box : null;

  // ── Lifecycle / user switching ─────────────────────────────────────────────

  /// Call this after sign-in and at app start (if already signed in).
  static Future<void> init() async {
    if (_uid == 'unknown') {
      if (kDebugMode) {
        debugPrint('🟡 UserPreferencesService.init() skipped – no user');
      }
      return;
    }
    await _ensureBoxForCurrentUser();
  }

  /// Ensures the correct box is open for the current signed-in user.
  static Future<void> _ensureBoxForCurrentUser() async {
    // If open for another user, close it first.
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

    // Open or reuse
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

  /// Ensures the box is ready before any read/write.
  static Future<Box?> _ensureBox() async {
    if (_box?.isOpen == true && _boxForUid == _uid) return _box;
    await _ensureBoxForCurrentUser();
    return _safeBox;
  }

  /// Optional: call on logout to fully close references.
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

  static Future<void> saveViewMode(ViewMode mode) async {
    final box = await _ensureBox();
    if (box != null) {
      await box.put(_keyViewMode, mode.index);
      if (kDebugMode) debugPrint('📂 Saved view mode: ${mode.name}');
    }
  }

  static Future<ViewMode> getSavedViewMode() async {
    final box = await _ensureBox();
    final index = box?.get(_keyViewMode) as int?;
    final mode = (index != null && index >= 0 && index < ViewMode.values.length)
        ? ViewMode.values[index]
        : ViewMode.grid;
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

    // If globally disabled, mark as done immediately.
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
        '📊 Bubble trigger check: shownOnce=$hasShownBubblesOnce, '
        'completed=$tutorialComplete',
      );
    }

    if (!hasShownBubblesOnce && !tutorialComplete) {
      await resetBubbles(); // clean slate; UI will call markBubblesShown() later
      if (kDebugMode) {
        debugPrint('🌟 Bubbles prepared for first-time user');
      }
    }
  }

  static Future<bool> get hasShownBubblesOnce async {
    final box = await _ensureBox();
    return box?.get(_keyBubblesShownOnce, defaultValue: false) as bool? ??
        false;
  }

  /// Call when the first bubble actually becomes visible.
  static Future<void> markBubblesShown() async {
    final box = await _ensureBox();
    if (box != null) await box.put(_keyBubblesShownOnce, true);
  }

  /// Clear all onboarding flags (simulate new user).
  static Future<void> markAsNewUser() async {
    final box = await _ensureBox();
    if (box != null) {
      await box.delete(_keyVaultTutorialComplete);
      await box.delete(_keyBubblesShownOnce);
      for (final key in _bubbleKeys) {
        await box.delete('bubbleDismissed_$key');
      }
      if (kDebugMode) {
        debugPrint('🎯 Onboarding flags cleared (new user mode)');
      }
    }
  }

  /// Small delay to allow session to prep flags before UI checks.
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

  /// 🔒 Internal: close and delete a Hive box
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
