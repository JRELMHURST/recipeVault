import 'package:hive/hive.dart';
import 'subscription_service.dart';

class AccessManager {
  static const _trialStartKey = 'trialStartDate';
  static const _trialUsageKey = 'trialRecipeCount';
  static const _proUsageKey = 'monthlyRecipeCount';
  static const _lastResetKey = 'lastUsageResetMonth';
  static const _isTrialUsedKey = 'trialAlreadyUsed';

  static const int trialLimit = 3;
  static const int proMonthlyLimit = 20;

  /// Call this once on app start to ensure monthly usage resets
  static Future<void> initialise() async {
    final box = await Hive.openBox('access');
    final now = DateTime.now();
    final lastMonth = box.get(_lastResetKey) as int?;

    if (lastMonth == null || lastMonth != now.month) {
      await box.put(_proUsageKey, 0);
      await box.put(_lastResetKey, now.month);
    }
  }

  /// Start trial if needed (used in PricingScreen)
  static Future<void> startTrialIfNeeded() async {
    final box = await Hive.openBox('access');
    final alreadyUsed = box.get(_isTrialUsedKey, defaultValue: false) as bool;
    if (alreadyUsed) return;

    if (!box.containsKey(_trialStartKey)) {
      await box.put(_trialStartKey, DateTime.now().toIso8601String());
      await box.put(_trialUsageKey, 0);
      await box.put(_isTrialUsedKey, true);
      await SubscriptionService().activateTrial();
    }
  }

  static Future<bool> isTrialActive() async {
    final box = await Hive.openBox('access');
    if (!box.containsKey(_trialStartKey)) return false;

    final start = DateTime.tryParse(box.get(_trialStartKey) ?? '');
    if (start == null) return false;

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

  /// Whether user can create a recipe (based on tier & limits)
  static Future<bool> canCreateRecipe() async {
    final sub = SubscriptionService();

    switch (sub.currentTier) {
      case Tier.masterChef:
        return true;

      case Tier.homeChef:
        final used = await getProRecipesUsedThisMonth();
        return used < proMonthlyLimit;

      case Tier.tasterTrial:
        if (!await isTrialActive()) return false;
        final used = await getTrialRecipesUsed();
        return used < trialLimit;
    }
  }

  /// Increments usage count depending on tier
  static Future<void> incrementRecipeUsage() async {
    final box = await Hive.openBox('access');
    final sub = SubscriptionService();

    switch (sub.currentTier) {
      case Tier.masterChef:
        return;

      case Tier.homeChef:
        final used = await getProRecipesUsedThisMonth();
        await box.put(_proUsageKey, used + 1);
        return;

      case Tier.tasterTrial:
        if (await isTrialActive()) {
          final used = await getTrialRecipesUsed();
          await box.put(_trialUsageKey, used + 1);
        }
        return;
    }
  }
}
