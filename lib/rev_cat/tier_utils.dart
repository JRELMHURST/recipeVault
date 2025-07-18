String resolveTier(String? entitlementId) {
  switch (entitlementId) {
    case 'taster_trial':
      return 'taster';
    case 'home_chef_monthly':
      return 'home_chef';
    case 'master_chef_monthly':
    case 'master_chef_yearly':
      return 'master_chef';
    default:
      return 'free'; // New safe fallback
  }
}
