import 'package:hive/hive.dart';

class SubscriptionService {
  static const _accessBox = 'access';
  static const _isSubscribedKey = 'isSubscribed';
  static const _isMasterChefKey = 'isMasterChef';

  /// Mock upgrade to Home Chef (Pro)
  static Future<void> activateHomeChef() async {
    final box = await Hive.openBox(_accessBox);
    await box.put(_isSubscribedKey, true);
    await box.put(_isMasterChefKey, false);
  }

  /// Mock upgrade to Master Chef
  static Future<void> activateMasterChef() async {
    final box = await Hive.openBox(_accessBox);
    await box.put(_isSubscribedKey, true);
    await box.put(_isMasterChefKey, true);
  }

  /// Reset all plans (used for logout/dev/testing)
  static Future<void> clearSubscriptionStatus() async {
    final box = await Hive.openBox(_accessBox);
    await box.put(_isSubscribedKey, false);
    await box.put(_isMasterChefKey, false);
  }

  /// Get current tier name (for UI labels)
  static Future<String> getCurrentTierName() async {
    final box = await Hive.openBox(_accessBox);
    final isPro = box.get(_isSubscribedKey, defaultValue: false) as bool;
    final isMaster = box.get(_isMasterChefKey, defaultValue: false) as bool;

    if (isMaster) return 'Master Chef';
    if (isPro) return 'Home Chef';
    return 'Taster';
  }
}
