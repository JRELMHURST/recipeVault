import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark }

class ThemeNotifier extends ChangeNotifier {
  static const _prefsKey = 'themeMode';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLight => _themeMode == ThemeMode.light;

  /// Load from SharedPreferences. Idempotent (won't notify if unchanged).
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);

    final parsed = _parseStored(saved);
    if (parsed == _themeMode) return;

    _themeMode = parsed;
    notifyListeners();
  }

  /// Update with AppThemeMode (light/dark). Idempotent.
  Future<void> updateTheme(AppThemeMode mode) async {
    final next = _fromAppThemeMode(mode);
    if (next == _themeMode) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
    _themeMode = next;
    notifyListeners();
  }

  /// Toggle between light and dark.
  Future<void> toggle() =>
      updateTheme(isDark ? AppThemeMode.light : AppThemeMode.dark);

  /// Backwards-compat convenience for UI code.
  AppThemeMode get currentAppThemeMode {
    switch (_themeMode) {
      case ThemeMode.light:
        return AppThemeMode.light;
      case ThemeMode.dark:
        return AppThemeMode.dark;
      case ThemeMode.system:
        // Not used in this app; default to light for consistency.
        return AppThemeMode.light;
    }
  }

  // ---- internals ----

  ThemeMode _fromAppThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  /// Parses stored strings with some legacy handling:
  ///  - 'light' / 'dark' (preferred)
  ///  - 'system' / 'auto' → default to light
  ///  - 'true' / 'false' → legacy boolean (true=dark)
  ThemeMode _parseStored(String? raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
      case null:
        return ThemeMode.light;
      case 'system':
      case 'auto':
        return ThemeMode.light; // app doesn't support system mode yet
      case 'true':
        return ThemeMode.dark; // legacy boolean mapping
      case 'false':
        return ThemeMode.light;
      default:
        return ThemeMode.light;
    }
  }
}
