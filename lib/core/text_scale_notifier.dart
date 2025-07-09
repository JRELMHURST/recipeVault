import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTextScale { small, medium, large }

class TextScaleNotifier extends ChangeNotifier {
  AppTextScale _scale = AppTextScale.medium;

  AppTextScale get scale => _scale;

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

  Future<void> loadScale() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('textScale') ?? 'medium';

    _scale = AppTextScale.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppTextScale.medium,
    );
    notifyListeners();
  }

  Future<void> updateScale(AppTextScale newScale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('textScale', newScale.name);
    _scale = newScale;
    notifyListeners();
  }
}
