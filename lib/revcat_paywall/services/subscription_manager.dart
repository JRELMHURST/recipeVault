import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';
import 'package:recipe_vault/revcat_paywall/services/access_manager.dart';

class SubscriptionManager {
  static final SubscriptionManager _instance = SubscriptionManager._internal();
  factory SubscriptionManager() => _instance;
  SubscriptionManager._internal();

  final SubscriptionService _service = SubscriptionService();

  Tier get currentTier => _service.currentTier;

  /// Whether the user has access to the app (trial or paid tier)
  bool get hasAccess => _service.hasAccess;

  /// Whether the user is currently on the Taster trial tier
  bool get isTrialTier => currentTier == Tier.tasterTrial;

  /// Whether the user has an active Taster trial
  bool get isTrialActive => _service.isTrialActive;

  /// Whether the user is subscribed to any paid tier
  bool get isPaidUser => _service.isPaidTier;

  /// Whether the user is subscribed to Master Chef
  bool get isMasterChef => currentTier == Tier.masterChef;

  /// Whether the user is subscribed to Home Chef
  bool get isHomeChef => currentTier == Tier.homeChef;

  /// Whether the user is a super user
  bool get isSuperUser => _service.isSuperUser;

  /// Whether the user can use translation
  Future<bool> canTranslate() async => _service.allowTranslation;

  /// Whether the user can create another recipe (respects tier and usage caps)
  Future<bool> canCreateRecipe() async => await AccessManager.canCreateRecipe();

  /// Increments usage count after recipe creation
  Future<void> incrementRecipeUsage() async =>
      await AccessManager.incrementRecipeUsage();
}
