import 'package:shared_preferences/shared_preferences.dart';

/// LocalFlags provides simple access to persistent local boolean flags.
/// Used for one-time screens, onboarding, or subscription status caching.
class LocalFlags {
  static const String _hasSeenWelcomeKey = 'hasSeenWelcome';
  static const String _tasterTrialUsedKey = 'taster_trial_used';

  static late SharedPreferences _prefs;

  /// Must be called once during app initialisation
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ========== Welcome Screen ==========
  static bool get hasSeenWelcome => _prefs.getBool(_hasSeenWelcomeKey) ?? false;
  static Future<void> setHasSeenWelcome(bool value) =>
      _prefs.setBool(_hasSeenWelcomeKey, value);

  // ========== Trial Usage ==========
  static bool get tasterTrialUsed =>
      _prefs.getBool(_tasterTrialUsedKey) ?? false;
  static Future<void> setTasterTrialUsed(bool value) =>
      _prefs.setBool(_tasterTrialUsedKey, value);

  /// ✅ Added async getter for compatibility with SubscriptionService
  static Future<bool> getTasterTrialUsed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tasterTrialUsedKey) ?? false;
  }

  /// Clears all flags (e.g. during logout or reset)
  static Future<void> reset() async {
    await _prefs.remove(_hasSeenWelcomeKey);
    await _prefs.remove(_tasterTrialUsedKey);
  }
}
