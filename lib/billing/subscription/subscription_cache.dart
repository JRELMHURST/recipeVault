import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class SubscriptionCache {
  static String _prefsBoxName(String uid) => 'userPrefs_$uid';
  static const _kCachedTier = 'cachedTier';
  static const _kCachedStatus = 'cachedStatus';
  static const _kCachedSpecial = 'cachedSpecialAccess';
  static const _kEverHadAccess = 'everHadAccess';

  Future<void> save({
    required String uid,
    required String tier,
    required bool active,
    required bool hasSpecialAccess,
  }) async {
    try {
      final boxName = _prefsBoxName(uid);
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box<dynamic>(boxName)
          : await Hive.openBox<dynamic>(boxName);
      await box.put(_kCachedTier, tier);
      await box.put(_kCachedStatus, active ? 'active' : 'inactive');
      await box.put(_kCachedSpecial, hasSpecialAccess);
      if (active) await box.put(_kEverHadAccess, true);
    } catch (e) {
      debugPrint('⚠️ Failed to cache tier: $e');
    }
  }

  Future<({String? tier, bool? special})> seed(String uid) async {
    try {
      final boxName = _prefsBoxName(uid);
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box<dynamic>(boxName)
          : await Hive.openBox<dynamic>(boxName);
      return (
        tier: (box.get(_kCachedTier) as String?)?.trim(),
        special: box.get(_kCachedSpecial) as bool?,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to seed tier from cache: $e');
      return (tier: null, special: null);
    }
  }

  Future<bool> everHadAccess(String uid) async {
    final boxName = _prefsBoxName(uid);
    final box = Hive.isBoxOpen(boxName)
        ? Hive.box<dynamic>(boxName)
        : await Hive.openBox<dynamic>(boxName);
    return (box.get(_kEverHadAccess) as bool?) ?? false;
  }
}
