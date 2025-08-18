// lib/screens/recipe_vault/view_mode_prefs.dart

import 'package:recipe_vault/services/user_preference_service.dart' as prefs;
import 'package:recipe_vault/screens/recipe_vault/vault_view_mode_notifier.dart'
    show ViewMode;

/// Persist UI ViewMode into prefs (bridged to PrefsViewMode).
class ViewModePrefs {
  /// Save a UI [ViewMode] to prefs.
  static Future<void> save(ViewMode mode) async {
    final mapped = _toPrefs(mode);
    await prefs.UserPreferencesService.saveViewMode(mapped);
  }

  /// Load last saved ViewMode (UI enum).
  /// Defaults to [ViewMode.grid] if unset.
  static Future<ViewMode> load() async {
    final saved = await prefs.UserPreferencesService.getSavedViewMode();
    return _fromPrefs(saved);
  }

  /* ---------- Enum bridge ---------- */

  static prefs.PrefsViewMode _toPrefs(ViewMode m) => switch (m) {
    ViewMode.list => prefs.PrefsViewMode.list,
    ViewMode.grid => prefs.PrefsViewMode.grid,
    ViewMode.compact => prefs.PrefsViewMode.compact,
  };

  static ViewMode _fromPrefs(prefs.PrefsViewMode m) => switch (m) {
    prefs.PrefsViewMode.list => ViewMode.list,
    prefs.PrefsViewMode.grid => ViewMode.grid,
    prefs.PrefsViewMode.compact => ViewMode.compact,
  };
}
