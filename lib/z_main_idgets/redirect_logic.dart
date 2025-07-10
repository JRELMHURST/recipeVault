import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';

/// Determines where to redirect a user based on auth, subscription, and onboarding state.
Future<String?> handleAuthRedirect(User? user) async {
  final prefs = await SharedPreferences.getInstance();

  // Not logged in → send to login
  if (user == null) return '/login';

  // Check subscription or trial access (already refreshed in main)
  final hasAccess =
      SubscriptionService().isPaidTier() ||
      SubscriptionService().isTrialActive();

  // If no valid access → show pricing
  if (!hasAccess) return '/pricing';

  // Check if user has seen the welcome screen
  final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;

  // If not seen → go to welcome
  if (!hasSeenWelcome) return '/welcome';

  // Everything ok → no redirect
  return null;
}
