import 'package:recipe_vault/payment_tiers/services/subscription_service.dart';
import 'package:recipe_vault/payment_tiers/services/access_manager.dart';

class SubscriptionManager {
  static final SubscriptionManager _instance = SubscriptionManager._internal();
  factory SubscriptionManager() => _instance;
  SubscriptionManager._internal();

  final _service = SubscriptionService();

  Tier get currentTier => _service.currentTier;

  /// Whether the user can currently access the app (trial or paid)
  bool get hasAccess {
    return currentTier == Tier.masterChef ||
        currentTier == Tier.homeChef ||
        _service.isTrialActive();
  }

  /// Whether the trial is still active
  bool get isTrialActive => _service.isTrialActive();

  /// Whether the user is on a free trial tier
  bool get isTrialTier => currentTier == Tier.tasterTrial;

  /// Whether the user is fully subscribed (any paid tier)
  bool get isPaidUser =>
      currentTier == Tier.homeChef || currentTier == Tier.masterChef;

  /// Whether the user is a Master Chef subscriber
  bool get isMasterChef => currentTier == Tier.masterChef;

  /// Whether the user is a Home Chef subscriber
  bool get isHomeChef => currentTier == Tier.homeChef;

  /// Whether the user can translate based on tier
  Future<bool> canTranslate() async {
    if (isMasterChef) return true;
    if (isHomeChef) {
      // Could later check limits here
      return true;
    }
    return false;
  }

  /// Whether the user can create another recipe
  Future<bool> canCreateRecipe() => AccessManager.canCreateRecipe();

  /// Updates usage count (per recipe creation)
  Future<void> incrementRecipeUsage() => AccessManager.incrementRecipeUsage();
}
