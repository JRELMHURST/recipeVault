import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class ThemeNotifier extends ChangeNotifier {
  static const _prefsKey = 'themeMode'; // stored values: light | dark | system

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLight => _themeMode == ThemeMode.light;
  bool get isSystem => _themeMode == ThemeMode.system;

  SharedPreferences? _prefs;

  /// Ensures prefs are ready (lazy).
  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Load from SharedPreferences. Idempotent (won't notify if unchanged).
  Future<void> loadTheme() async {
    final prefs = await _ensurePrefs();
    final saved = prefs.getString(_prefsKey);
    final parsed = _parseStored(saved);
    if (parsed == _themeMode) return;
    _themeMode = parsed;
    notifyListeners();
  }

  /// Set using Flutter's ThemeMode directly (light/dark/system).
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    final prefs = await _ensurePrefs();
    await prefs.setString(_prefsKey, _serialize(mode));
    _themeMode = mode;
    notifyListeners();
  }

  /// Update using your app enum (kept for backwards-compat).
  Future<void> updateTheme(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return setThemeMode(ThemeMode.light);
      case AppThemeMode.dark:
        return setThemeMode(ThemeMode.dark);
      case AppThemeMode.system:
        return setThemeMode(ThemeMode.system);
    }
  }

  /// Toggle between light and dark (if currently system, treat as light → dark).
  Future<void> toggle() {
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    return setThemeMode(next);
  }

  /// Backwards-compat convenience for UI code.
  AppThemeMode get currentAppThemeMode {
    switch (_themeMode) {
      case ThemeMode.light:
        return AppThemeMode.light;
      case ThemeMode.dark:
        return AppThemeMode.dark;
      case ThemeMode.system:
        return AppThemeMode.system;
    }
  }

  // ---------------- internals ----------------

  String _serialize(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// Parses stored strings with legacy handling:
  ///  - 'light' / 'dark' / 'system' (preferred)
  ///  - 'auto' → 'system'
  ///  - 'true' / 'false' → legacy boolean (true=dark)
  ThemeMode _parseStored(String? raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'auto':
        return ThemeMode.system; // legacy mapping
      case 'true':
        return ThemeMode.dark; // legacy boolean mapping
      case 'false':
        return ThemeMode.light;
      case null:
      default:
        return ThemeMode.light;
    }
  }
}
