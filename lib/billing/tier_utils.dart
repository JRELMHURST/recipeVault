import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Maps a RevenueCat identifier to in-app tiers.
/// Accepts a productIdentifier (e.g. "master_chef_yearly") and,
/// optionally, entitlement keys if you decide to pass those.
/// Returns: "home_chef" | "master_chef" | "none"
String resolveTier(String? rcId) {
  if (rcId == null || rcId.trim().isEmpty) {
    if (kDebugMode) print('🧾 Resolved tier from RC id <null> → none');
    return 'none';
  }

  final id = _normalize(rcId);

  // Known product identifiers (the canonical source in your app)
  const homeChefProducts = {'home_chef_monthly'};
  const masterChefProducts = {'master_chef_monthly', 'master_chef_yearly'};

  // Optional: entitlement keys (only if you ever pass keys instead of product ids)
  const homeChefEntitlements = {'home_chef'};
  const masterChefEntitlements = {'master_chef'};

  String tier;
  if (homeChefProducts.contains(id) || homeChefEntitlements.contains(id)) {
    tier = 'home_chef';
  } else if (masterChefProducts.contains(id) ||
      masterChefEntitlements.contains(id)) {
    tier = 'master_chef';
  } else {
    tier = 'none';
  }

  if (kDebugMode) print('🧾 Resolved tier from RC id "$rcId" → $tier');
  return tier;
}

/// Paid if not 'none'.
bool isPaidTier(String tier) => tier == 'home_chef' || tier == 'master_chef';

/// Derive tier directly from a RevenueCat snapshot using the first active
/// entitlement's **productIdentifier** (not entitlement key).
String resolveTierFromCustomerInfo(CustomerInfo info) {
  if (info.entitlements.active.isEmpty) return 'none';
  final EntitlementInfo e = info.entitlements.active.values.first;
  return resolveTier(e.productIdentifier);
}

String _normalize(String s) => s.trim().toLowerCase();
