/// Frontend fallback limits used when Firestore `tierLimits/{tier}`
/// isn't available yet (offline/first run) or errors.
class TierLimitsFallback {
  static const Map<String, Map<String, int>> byTier = {
    'home_chef': {
      'recipeUsage': 20,
      'translatedRecipeUsage': 5,
      'imageUsage': 30,
    },
    'master_chef': {
      'recipeUsage': 100,
      'translatedRecipeUsage': 20,
      'imageUsage': 250,
    },
  };

  /// Returns a safe copy to avoid mutating the const map.
  static Map<String, int>? forTier(String tier) {
    final limits = byTier[tier];
    return limits != null ? Map<String, int>.from(limits) : null;
  }
}
