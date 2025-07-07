import 'package:hive/hive.dart';

class AccessManager {
  static const _trialStartKey = 'trialStartDate';
  static const _trialUsageKey = 'trialRecipeCount';
  static const _proUsageKey = 'monthlyRecipeCount';
  static const _lastResetKey = 'lastUsageResetMonth';
  static const _isTrialUsedKey = 'trialAlreadyUsed';

  static const int trialLimit = 3;
  static const int proMonthlyLimit = 20;

  /// Call this once on app start to ensure monthly reset logic is enforced
  static Future<void> initialise() async {
    final box = await Hive.openBox('access');

    final now = DateTime.now();
    final lastMonth = box.get(_lastResetKey) as int?;

    if (lastMonth == null || lastMonth != now.month) {
      await box.put(_proUsageKey, 0);
      await box.put(_lastResetKey, now.month);
    }
  }

  static Future<void> startTrialIfNeeded() async {
    final box = await Hive.openBox('access');

    final alreadyUsed = box.get(_isTrialUsedKey, defaultValue: false) as bool;
    if (alreadyUsed) return;

    if (!box.containsKey(_trialStartKey)) {
      await box.put(_trialStartKey, DateTime.now().toIso8601String());
      await box.put(_trialUsageKey, 0);
      await box.put(_isTrialUsedKey, true);
    }
  }

  static Future<bool> isTrialActive() async {
    final box = await Hive.openBox('access');
    if (!box.containsKey(_trialStartKey)) return false;

    final start = DateTime.parse(box.get(_trialStartKey));
    return DateTime.now().difference(start).inDays < 7;
  }

  static Future<int> getTrialRecipesUsed() async {
    final box = await Hive.openBox('access');
    return box.get(_trialUsageKey, defaultValue: 0) as int;
  }

  static Future<int> getProRecipesUsedThisMonth() async {
    final box = await Hive.openBox('access');
    return box.get(_proUsageKey, defaultValue: 0) as int;
  }

  /// Simulated flag for whether user has paid.
  static Future<bool> isProUser() async {
    final box = await Hive.openBox('access');
    return box.get('isSubscribed', defaultValue: false) as bool;
  }

  /// Simulated flag for whether user is on Master Chef tier.
  static Future<bool> isMasterChef() async {
    final box = await Hive.openBox('access');
    return box.get('isMasterChef', defaultValue: false) as bool;
  }

  static Future<bool> canCreateRecipe() async {
    if (await isMasterChef()) return true;

    if (await isProUser()) {
      final used = await getProRecipesUsedThisMonth();
      return used < proMonthlyLimit;
    }

    if (await isTrialActive()) {
      final used = await getTrialRecipesUsed();
      return used < trialLimit;
    }

    return false;
  }

  static Future<void> incrementRecipeUsage() async {
    final box = await Hive.openBox('access');

    if (await isMasterChef()) return;

    if (await isProUser()) {
      final used = await getProRecipesUsedThisMonth();
      await box.put(_proUsageKey, used + 1);
      return;
    }

    if (await isTrialActive()) {
      final used = await getTrialRecipesUsed();
      await box.put(_trialUsageKey, used + 1);
    }
  }
}
