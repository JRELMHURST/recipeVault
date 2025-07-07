import 'package:hive/hive.dart';

enum Tier { tasterTrial, homeChef, masterChef }

class SubscriptionService {
  static const _accessBox = 'access';
  static const _isSubscribedKey = 'isSubscribed';
  static const _isMasterChefKey = 'isMasterChef';
  static const _trialEndsAtKey = 'trialEndsAt';

  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  Tier _currentTier = Tier.tasterTrial;
  Tier get currentTier => _currentTier;

  /// Initialise service and determine tier
  Future<void> init() async {
    final box = await Hive.openBox(_accessBox);
    final isPro = box.get(_isSubscribedKey, defaultValue: false) as bool;
    final isMaster = box.get(_isMasterChefKey, defaultValue: false) as bool;
    final trialEndsAt = box.get(_trialEndsAtKey);

    final now = DateTime.now();
    final trialExpired =
        trialEndsAt is int &&
        DateTime.fromMillisecondsSinceEpoch(trialEndsAt).isBefore(now);

    if (isMaster) {
      _currentTier = Tier.masterChef;
    } else if (isPro) {
      _currentTier = Tier.homeChef;
    } else if (!trialExpired) {
      _currentTier = Tier.tasterTrial;
    } else {
      _currentTier = Tier.tasterTrial; // fallback
    }
  }

  /// Start 7-day free trial
  Future<void> activateTrial() async {
    final box = await Hive.openBox(_accessBox);
    final endsAt = DateTime.now()
        .add(const Duration(days: 7))
        .millisecondsSinceEpoch;
    await box.put(_trialEndsAtKey, endsAt);
    _currentTier = Tier.tasterTrial;
  }

  /// Upgrade to Home Chef
  Future<void> activateHomeChef() async {
    final box = await Hive.openBox(_accessBox);
    await box.put(_isSubscribedKey, true);
    await box.put(_isMasterChefKey, false);
    _currentTier = Tier.homeChef;
  }

  /// Upgrade to Master Chef
  Future<void> activateMasterChef() async {
    final box = await Hive.openBox(_accessBox);
    await box.put(_isSubscribedKey, true);
    await box.put(_isMasterChefKey, true);
    _currentTier = Tier.masterChef;
  }

  /// Clear all subscription data (for logout/dev/testing)
  Future<void> clearSubscriptionStatus() async {
    final box = await Hive.openBox(_accessBox);
    await box.put(_isSubscribedKey, false);
    await box.put(_isMasterChefKey, false);
    await box.delete(_trialEndsAtKey);
    _currentTier = Tier.tasterTrial;
  }

  /// Human-friendly tier name
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

  /// Whether trial is still active
  bool isTrialActive() {
    final box = Hive.box(_accessBox);
    final trialEndsAt = box.get(_trialEndsAtKey);
    if (trialEndsAt is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        trialEndsAt,
      ).isAfter(DateTime.now());
    }
    return false;
  }

  /// Returns when trial ends (or null)
  DateTime? getTrialEndDate() {
    final box = Hive.box(_accessBox);
    final trialEndsAt = box.get(_trialEndsAtKey);
    if (trialEndsAt is int) {
      return DateTime.fromMillisecondsSinceEpoch(trialEndsAt);
    }
    return null;
  }

  /// Check if user is already on the given tier
  bool isCurrentTier(Tier tier) => _currentTier == tier;
}
