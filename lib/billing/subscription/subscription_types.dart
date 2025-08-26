import 'package:purchases_flutter/purchases_flutter.dart';

/// Mapping helper — ideally generated from backend (TS ⇆ Dart)
String productToTier(String productId) {
  final id = productId.toLowerCase();
  if (id.contains('home_chef')) return 'home_chef';
  if (id.contains('master_chef')) return 'master_chef';
  return 'none';
}

enum EntitlementStatus { checking, active, inactive }

bool get isMobilePlatformSupported => true; // guarded at call sites anyway

/// Utilities around RC entitlements
class EntitlementUtils {
  static String resolveTier(Map<String, EntitlementInfo> ents) {
    for (final e in ents.values) {
      final tier = productToTier(e.productIdentifier);
      if (tier != 'none') return tier;
    }
    return 'none';
  }

  static EntitlementInfo? activeForTier(
    Map<String, EntitlementInfo> ents,
    String tier,
  ) {
    for (final e in ents.values) {
      if (productToTier(e.productIdentifier) == tier) return e;
    }
    return null;
  }
}
