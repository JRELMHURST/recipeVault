/// Converts RevenueCat entitlement ID to internal tier
String resolveTier(String? entitlementId) {
  switch (entitlementId) {
    case 'master_chef_yearly':
    case 'master_chef_monthly':
      return 'master_chef';
    case 'home_chef_monthly':
      return 'home_chef';
    default:
      return 'taster'; // fallback
  }
}
