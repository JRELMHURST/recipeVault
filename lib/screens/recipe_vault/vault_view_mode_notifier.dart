import 'package:flutter/material.dart';
import 'package:recipe_vault/services/user_preference_service.dart' as prefs;

// UI enum used by widgets throughout the app
enum ViewMode { list, grid, compact }

class VaultViewModeNotifier extends ChangeNotifier {
  ViewMode _mode = ViewMode.grid;
  ViewMode get mode => _mode;

  IconData get icon => switch (_mode) {
    ViewMode.list => Icons.view_agenda_rounded,
    ViewMode.grid => Icons.grid_view_rounded,
    ViewMode.compact => Icons.view_module_rounded,
  };

  void toggle() {
    final all = ViewMode.values;
    final next = all[(all.indexOf(_mode) + 1) % all.length];
    set(next);
  }

  void set(ViewMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    // persist to prefs
    prefs.UserPreferencesService.saveViewMode(_toPrefs(mode));
    notifyListeners();
  }

  Future<void> loadFromPrefs() async {
    final saved =
        await prefs.UserPreferencesService.getSavedViewMode(); // PrefsViewMode
    final mapped = _fromPrefs(saved);
    if (_mode != mapped) {
      _mode = mapped;
      notifyListeners();
    }
  }

  // ---- enum bridges ----
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
