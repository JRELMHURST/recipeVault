import 'package:hive/hive.dart';

class UserPreferencesService {
  static const String _boxName = 'userPrefs';
  static const String _keyViewMode = 'viewMode';
  static const String _keyVaultTutorialComplete = 'vaultTutorialComplete';

  static late Box _box;

  /// Opens the Hive box for user preferences (called in main.dart)
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Gets the current view mode (0 = list, 1 = grid, 2 = compact, etc.)
  static int getViewMode() {
    return _box.get(_keyViewMode, defaultValue: 0) as int;
  }

  /// Saves the selected view mode
  static Future<void> setViewMode(int mode) async {
    await _box.put(_keyViewMode, mode);
  }

  /// Marks the vault tutorial as completed
  static Future<void> markVaultTutorialCompleted() async {
    await _box.put(_keyVaultTutorialComplete, true);
  }

  /// Checks if the vault tutorial has been completed
  static Future<bool> hasCompletedVaultTutorial() async {
    return _box.get(_keyVaultTutorialComplete, defaultValue: false) as bool;
  }

  /// Optional: Reset the tutorial completion flag (for dev/testing)
  static Future<void> resetVaultTutorial() async {
    await _box.delete(_keyVaultTutorialComplete);
  }

  /// Optional: clear all user preferences
  static Future<void> clearAll() async {
    await _box.clear();
  }

  /// Optional: get raw value (for future custom prefs)
  static dynamic get(String key) => _box.get(key);

  /// Optional: set raw value (for future custom prefs)
  static Future<void> set(String key, dynamic value) async {
    await _box.put(key, value);
  }
}
