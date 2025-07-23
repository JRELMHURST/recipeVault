import 'package:hive/hive.dart';

class UserPreferencesService {
  static const String _boxName = 'userPrefs';
  static const String _keyViewMode = 'viewMode';
  static const String _keyVaultTutorialComplete = 'vaultTutorialComplete';

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
  }

  static Future<bool> hasCompletedVaultTutorial() async {
    return _box.get(_keyVaultTutorialComplete, defaultValue: false) as bool;
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// 💬 Bubble Dismissals (Generalised)
  static Future<void> markBubbleDismissed(String key) async {
    await _box.put('bubbleDismissed_$key', true);
  }

  static Future<bool> hasDismissedBubble(String key) async {
    return _box.get('bubbleDismissed_$key', defaultValue: false) as bool;
  }

  static Future<bool> shouldShowBubble(String key) async {
    return !(await hasDismissedBubble(key));
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// 🔁 Bubble Helpers (legacy-style for each bubble)
  static Future<void> dismissScanBubble() async => markBubbleDismissed('scan');
  static Future<void> dismissViewToggleBubble() async =>
      markBubbleDismissed('viewToggle');
  static Future<void> dismissLongPressBubble() async =>
      markBubbleDismissed('longPress');

  static Future<bool> shouldShowScanBubble() async =>
      !(await hasDismissedBubble('scan'));
  static Future<bool> shouldShowViewToggleBubble() async =>
      !(await hasDismissedBubble('viewToggle'));
  static Future<bool> shouldShowLongPressBubble() async =>
      !(await hasDismissedBubble('longPress'));

  // ──────────────────────────────────────────────────────────────────────────────
  /// 🧪 Developer/Test Utilities
  static Future<void> resetVaultTutorial() async {
    await _box.delete(_keyVaultTutorialComplete);
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
