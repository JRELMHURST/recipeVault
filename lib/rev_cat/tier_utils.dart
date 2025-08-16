import 'package:flutter/foundation.dart';

/// Maps RevenueCat identifiers to in-app tiers.
/// - Accepts either a productIdentifier (e.g. "master_chef_yearly")
///   or an entitlement identifier you may choose to use.
/// - Trial handling is done elsewhere (e.g. via `trialEndDate`).
///
/// Returns: "home_chef" | "master_chef" | "none"
String resolveTier(String? rcId) {
  if (rcId == null || rcId.isEmpty) {
    if (kDebugMode) print('🧾 Resolved tier from entitlement "<null>" → none');
    return 'none';
  }

  final id = rcId.toLowerCase().trim();

  // Known product identifiers (RevenueCat -> App tiers)
  const homeChefProducts = {'home_chef_monthly'};
  const masterChefProducts = {'master_chef_monthly', 'master_chef_yearly'};

  // If you ever use entitlement identifiers directly, map them here too.
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
