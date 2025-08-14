import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'app_bootstrap.dart';
import 'recipe_vault_app.dart';
import 'core/theme_notifier.dart';
import 'core/text_scale_notifier.dart';
import 'core/language_provider.dart'; // ⬅️ NEW
import 'rev_cat/subscription_service.dart';
import 'services/user_session_service.dart';

final subscriptionService = SubscriptionService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.ensureReady();

  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null && !user.isAnonymous) {
      debugPrint('🧍 FirebaseAuth: User signed in with UID = ${user.uid}');

      try {
        await Purchases.logOut(); // Avoid stale RevenueCat session
        await Purchases.logIn(user.uid);
        debugPrint('🛒 RevenueCat logged in as ${user.uid}');
      } catch (e) {
        debugPrint('❌ RevenueCat login failed: $e');
      }

      await UserSessionService.init();
    } else {
      debugPrint('👋 FirebaseAuth: User signed out or null');
      await UserSessionService.logoutReset(); // Full reset incl. Hive + RevenueCat
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()),
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..load(),
        ), // ⬅️ NEW
        ChangeNotifierProvider.value(value: subscriptionService),
      ],
      child: const RecipeVaultApp(),
    ),
  );
}
