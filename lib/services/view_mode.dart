import 'package:flutter/foundation.dart';
import 'package:recipe_vault/services/user_preference_service.dart';

/// 🧭 User-facing view modes
enum ViewMode { list, grid, compact }

/// 🧩 Extensions for labels and assets
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

/// 💾 View mode service for saving/loading
class ViewModeService {
  static Future<ViewMode> getViewMode() async {
    final mode = await UserPreferencesService.getSavedViewMode();
    return mode;
  }

  static Future<void> setViewMode(ViewMode mode) async {
    await UserPreferencesService.saveViewMode(mode);
    if (kDebugMode) print('💾 View mode saved: ${mode.label}');
  }
}
