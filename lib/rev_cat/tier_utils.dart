import 'package:flutter/foundation.dart';

/// Maps entitlement IDs from RevenueCat to app subscription tiers.
/// Assumes trial status is handled separately (e.g. via `trialEndDate`).
String resolveTier(String? entitlementId) {
  final tier = switch (entitlementId) {
    'home_chef_monthly' => 'home_chef',
    'master_chef_monthly' || 'master_chef_yearly' => 'master_chef',
    _ => 'free',
  };

  if (kDebugMode) {
    print('🧾 Resolved tier from entitlement "$entitlementId" → $tier');
  }

  return tier;
}
