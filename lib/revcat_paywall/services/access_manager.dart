import 'package:hive/hive.dart';
import 'subscription_service.dart';

class AccessManager {
  static const _proUsageKey = 'monthlyRecipeCount';
  static const _lastResetKey = 'lastUsageReset';
  static const _trialUsageKey = 'trialRecipeCount';

  static const int trialLimit = 3;
  static const int proMonthlyLimit = 20;

  /// Call this once on app start to ensure monthly usage resets
  static Future<void> initialise() async {
    final box = await Hive.openBox('access');
    final now = DateTime.now();
    final current = now.year * 100 + now.month;
    final lastReset = box.get(_lastResetKey, defaultValue: 0) as int;

    if (lastReset != current) {
      await box.put(_proUsageKey, 0);
      await box.put(_lastResetKey, current);
    }
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
    await sub.refresh(); // Ensure currentTier is loaded
    final tier = sub.currentTier;
    final trialActive = sub.isTrialActive();

    switch (tier) {
      case Tier.masterChef:
        return true;

      case Tier.homeChef:
        final used = await getProRecipesUsedThisMonth();
        return used < proMonthlyLimit;

      case Tier.tasterTrial:
        if (!trialActive) return false;
        final used = await getTrialRecipesUsed();
        return used < trialLimit;
    }
  }

  /// Increments usage count depending on tier
  static Future<void> incrementRecipeUsage() async {
    final box = await Hive.openBox('access');
    final sub = SubscriptionService();
    await sub.refresh();
    final tier = sub.currentTier;
    final trialActive = sub.isTrialActive();

    switch (tier) {
      case Tier.masterChef:
        return;

      case Tier.homeChef:
        final used = await getProRecipesUsedThisMonth();
        await box.put(_proUsageKey, used + 1);
        return;

      case Tier.tasterTrial:
        if (trialActive) {
          final used = await getTrialRecipesUsed();
          await box.put(_trialUsageKey, used + 1);
        }
        return;
    }
  }
}
