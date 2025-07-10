import 'package:purchases_flutter/purchases_flutter.dart';

/// Your app's defined subscription tiers
enum Tier { none, tasterTrial, homeChef, masterChef }

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  Tier _currentTier = Tier.none;
  Tier get currentTier => _currentTier;

  /// Call this once during app start (after Purchases.configure)
  Future<void> init() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final entitlements = info.entitlements.active;

      if (entitlements.containsKey('master_chef_monthly') ||
          entitlements.containsKey('master_chef_yearly')) {
        _currentTier = Tier.masterChef;
      } else if (entitlements.containsKey('home_chef_monthly')) {
        _currentTier = Tier.homeChef;
      } else if (entitlements.containsKey('taster')) {
        _currentTier = Tier.tasterTrial;
      } else {
        _currentTier = Tier.none;
      }
    } catch (e) {
      _currentTier = Tier.none; // fallback on RevenueCat error
    }
  }

  /// Friendly label for displaying the current tier
  String getCurrentTierName() {
    switch (_currentTier) {
      case Tier.tasterTrial:
        return 'Taster Trial';
      case Tier.homeChef:
        return 'Home Chef';
      case Tier.masterChef:
        return 'Master Chef';
      case Tier.none:
        return 'No Access';
    }
  }

  bool isPaidTier() =>
      _currentTier == Tier.homeChef || _currentTier == Tier.masterChef;

  bool isCurrentTier(Tier tier) => _currentTier == tier;

  bool isTrialActive() => _currentTier == Tier.tasterTrial;

  bool get hasAccess =>
      isTrialActive() || isPaidTier(); // will return false for Tier.none

  bool get allowTranslation =>
      _currentTier == Tier.homeChef || _currentTier == Tier.masterChef;

  bool get allowUnlimitedTranslation => _currentTier == Tier.masterChef;

  bool get allowSmartSearch => _currentTier == Tier.masterChef;

  bool get allowImageUpload =>
      _currentTier != Tier.tasterTrial && _currentTier != Tier.none;

  bool get allowCloudSync =>
      _currentTier != Tier.tasterTrial && _currentTier != Tier.none;

  /// Refresh the tier manually (e.g. after purchase or restore)
  Future<void> refresh() async => await init();

  /// Manually activate the Taster Trial if user opts in
  Future<void> activateTasterTrial() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final hasTrial = info.entitlements.active.containsKey('taster');

      if (!hasTrial) {
        // ⛳ Add logic to activate via backend or Firestore
        _currentTier = Tier.tasterTrial;
      }

      await refresh(); // Always refresh to confirm
    } catch (e) {
      rethrow;
    }
  }

  @override
  String toString() => 'SubscriptionService(currentTier: $_currentTier)';
}
