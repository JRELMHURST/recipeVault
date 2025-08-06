import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:recipe_vault/app_bootstrap.dart';
import 'package:recipe_vault/recipe_vault_app.dart';
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/services/user_session_service.dart';

final subscriptionService = SubscriptionService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.ensureReady();

  // 🔁 Start listening to auth changes before UI builds
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null && !user.isAnonymous) {
      debugPrint('🧍 FirebaseAuth: User signed in with UID = ${user.uid}');

      try {
        await Purchases.logIn(user.uid);
        debugPrint('🛒 RevenueCat logged in as ${user.uid}');
      } catch (e) {
        debugPrint('❌ RevenueCat login failed: $e');
      }

      await UserSessionService.init(); // ✅ Safe session init after RC login
    } else {
      debugPrint('🧍 FirebaseAuth: No user signed in');
      await UserSessionService.logoutReset(); // 🧼 Cancel streams + close Hive
    }
  });

  // 🎯 App UI entrypoint
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()),
        ChangeNotifierProvider.value(value: subscriptionService),
      ],
      child: const RecipeVaultApp(),
    ),
  );
}
