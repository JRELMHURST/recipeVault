import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Your app's defined subscription tiers
enum Tier { none, tasterTrial, homeChef, masterChef }

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  Tier _currentTier = Tier.none;
  bool _superUser = false;

  Tier get currentTier => _currentTier;
  bool get isSuperUser => _superUser;

  late final SharedPreferences _prefs;
  static const _trialUsedKey = 'taster_trial_used';

  /// Call this once during app start (after Purchases.configure)
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();

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

      // ✅ Ensure user is available (await auth restore if needed)
      final user =
          FirebaseAuth.instance.currentUser ??
          await FirebaseAuth.instance.authStateChanges().first;

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        _superUser = doc.data()?['superUser'] == true;
        if (_superUser && kDebugMode) {
          if (kDebugMode) {
            print('🛠 SuperUser override enabled');
          }
        }
      } else {
        _superUser = false;
      }
    } catch (e, stack) {
      _currentTier = Tier.none;
      _superUser = false;
      if (kDebugMode) {
        print('⚠️ SubscriptionService init failed: $e');
        print(stack);
      }
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

  bool get isPaidTier =>
      _currentTier == Tier.homeChef || _currentTier == Tier.masterChef;

  bool isCurrentTier(Tier tier) => _currentTier == tier;

  bool get isTrialActive => _currentTier == Tier.tasterTrial;

  bool get hasAccess => _superUser || isTrialActive || isPaidTier;

  bool get allowTranslation =>
      _superUser ||
      _currentTier == Tier.homeChef ||
      _currentTier == Tier.masterChef;

  bool get allowUnlimitedTranslation =>
      _superUser || _currentTier == Tier.masterChef;

  bool get allowSmartSearch => _superUser || _currentTier == Tier.masterChef;

  bool get allowImageUpload =>
      _superUser ||
      (_currentTier != Tier.tasterTrial && _currentTier != Tier.none);

  bool get allowCloudSync =>
      _superUser ||
      (_currentTier != Tier.tasterTrial && _currentTier != Tier.none);

  bool get hasTasterTrialBeenUsed => _prefs.getBool(_trialUsedKey) ?? false;

  /// ✅ Returns true if any active tier is present
  bool get hasActiveSubscription => hasAccess;

  /// Refresh the tier manually (e.g. after purchase or restore)
  Future<void> refresh() async => await init();

  /// Manually activate the Taster Trial if user opts in
  Future<void> activateTasterTrial() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final hasTrial = info.entitlements.active.containsKey('taster');

      if (!hasTrial) {
        _currentTier = Tier.tasterTrial;
        await _prefs.setBool(_trialUsedKey, true);
      }

      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  @override
  String toString() =>
      'SubscriptionService(currentTier: $_currentTier, superUser: $_superUser)';
}
