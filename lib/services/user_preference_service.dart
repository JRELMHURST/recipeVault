// lib/core/user_preferences_service.dart
import 'package:hive/hive.dart';

class UserPreferencesService {
  static const _boxName = 'userPrefs';
  static const _keyViewMode = 'viewMode';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  static int getViewMode() {
    final box = Hive.box(_boxName);
    return box.get(_keyViewMode, defaultValue: 0); // default to list
  }

  static Future<void> setViewMode(int mode) async {
    final box = Hive.box(_boxName);
    await box.put(_keyViewMode, mode);
  }
}
