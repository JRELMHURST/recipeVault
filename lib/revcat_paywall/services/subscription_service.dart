import 'package:purchases_flutter/purchases_flutter.dart';

/// Your app's defined subscription tiers
enum Tier { tasterTrial, homeChef, masterChef }

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  Tier _currentTier = Tier.tasterTrial;
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
      } else {
        _currentTier = Tier.tasterTrial;
      }
    } catch (e) {
      _currentTier = Tier.tasterTrial; // fallback if RevenueCat errors
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
    }
  }

  /// Whether the current tier is a paid subscription
  bool isPaidTier() =>
      _currentTier == Tier.homeChef || _currentTier == Tier.masterChef;

  /// Check if current tier matches
  bool isCurrentTier(Tier tier) => _currentTier == tier;

  /// Check if user is on the free trial tier
  bool isTrialActive() => _currentTier == Tier.tasterTrial;

  /// Whether the user has access to the app (trial or paid tier)
  bool get hasAccess => isTrialActive() || isPaidTier();

  /// Per-tier feature access logic
  bool get allowTranslation =>
      _currentTier == Tier.homeChef || _currentTier == Tier.masterChef;

  bool get allowUnlimitedTranslation => _currentTier == Tier.masterChef;

  bool get allowSmartSearch => _currentTier == Tier.masterChef;

  bool get allowImageUpload => _currentTier != Tier.tasterTrial;

  bool get allowCloudSync => _currentTier != Tier.tasterTrial;

  /// Refresh the tier manually (e.g. after a purchase or restore)
  Future<void> refresh() async => await init();

  /// Manually activate the Taster Trial if user opts in
  Future<void> activateTasterTrial() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final hasTrial = info.entitlements.active.containsKey('taster');

      if (!hasTrial) {
        // Logic placeholder — use Firestore or a backend API to flag trial if needed
        _currentTier = Tier.tasterTrial;
        // You may also want to call Purchases.logIn(...) if custom user identifiers apply
      }
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  /// Debug helper
  @override
  String toString() => 'SubscriptionService(currentTier: $_currentTier)';
}
