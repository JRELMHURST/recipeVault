/// Converts a RevenueCat entitlement ID to your internal tier string.
String resolveTier(String? entitlementId) {
  switch (entitlementId) {
    case 'master_chef_yearly':
    case 'master_chef_monthly':
      return 'master_chef';
    case 'home_chef_monthly':
      return 'home_chef';
    case 'taster_trial':
      return 'taster';
    default:
      return 'taster'; // Fallback for no entitlement
  }
}
