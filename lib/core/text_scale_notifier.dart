import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTextScale { small, medium, large }

class TextScaleNotifier extends ChangeNotifier {
  static const _prefsKey = 'textScale';

  AppTextScale _scale = AppTextScale.medium;

  AppTextScale get scale => _scale;

  /// Numeric factor for scaling.
  double get scaleFactor {
    switch (_scale) {
      case AppTextScale.small:
        return 0.85;
      case AppTextScale.medium:
        return 1.0;
      case AppTextScale.large:
        return 1.25;
    }
  }

  /// A TextScaler you can pass straight into MediaQuery.copyWith.
  TextScaler get textScaler => TextScaler.linear(scaleFactor);

  /// Idempotent load from SharedPreferences.
  Future<void> loadScale() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);

    AppTextScale parsed;

    if (stored == null) {
      parsed = AppTextScale.medium;
    } else {
      // Primary: parse enum by name
      parsed = AppTextScale.values.firstWhere(
        (e) => e.name == stored,
        orElse: () {
          // Legacy migration: numeric factors stored as string (e.g., "1.25")
          final legacy = double.tryParse(stored);
          if (legacy != null) {
            if (legacy <= 0.9) return AppTextScale.small;
            if (legacy >= 1.2) return AppTextScale.large;
            return AppTextScale.medium;
          }
          return AppTextScale.medium;
        },
      );
    }

    if (parsed == _scale) return; // no-op if nothing changed
    _scale = parsed;
    notifyListeners();
  }

  Future<void> updateScale(AppTextScale newScale) async {
    if (newScale == _scale) return; // no-op
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, newScale.name);
    _scale = newScale;
    notifyListeners();
  }

  /// Convenience helper to apply this scale to an existing MediaQueryData.
  MediaQueryData applyTo(MediaQueryData base) =>
      base.copyWith(textScaler: textScaler);
}
