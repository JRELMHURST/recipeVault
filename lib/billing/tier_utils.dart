import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Maps RevenueCat identifiers to in-app tiers.
/// Accepts either a productIdentifier (e.g. "master_chef_yearly")
/// or an entitlement identifier you may choose to use.
///
/// Returns one of: "home_chef" | "master_chef" | "none"
String resolveTier(String? rcId) {
  if (rcId == null || rcId.isEmpty) {
    if (kDebugMode) print('🧾 Resolved tier from entitlement "<null>" → none');
    return 'none';
  }

  final id = _normalize(rcId);

  // Known product identifiers (RevenueCat -> App tiers)
  const homeChefProducts = {'home_chef_monthly'};
  const masterChefProducts = {'master_chef_monthly', 'master_chef_yearly'};

  // (Optional) entitlement keys if you ever use them directly
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

  if (kDebugMode) {
    print('🧾 Resolved tier from entitlement "$rcId" → $tier');
  }
  return tier;
}

/// Convenience: true if a given tier is paid (anything but 'none').
bool isPaidTier(String tier) => tier == 'home_chef' || tier == 'master_chef';

/// Convenience: derive tier directly from a RevenueCat CustomerInfo snapshot.
/// Picks the first active entitlement’s productIdentifier and resolves it.
String resolveTierFromCustomerInfo(CustomerInfo info) {
  if (info.entitlements.active.isEmpty) return 'none';
  final EntitlementInfo e = info.entitlements.active.values.first;
  return resolveTier(e.productIdentifier);
}

String _normalize(String s) => s.trim().toLowerCase();
