// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import 'services/notification_service.dart';
import 'firebase_options.dart';
import 'core/theme_notifier.dart';
import 'core/text_scale_notifier.dart';
import 'model/recipe_card_model.dart';
import 'model/category_model.dart';
import 'services/user_preference_service.dart';
import 'services/user_session_service.dart';
import 'rev_cat/subscription_service.dart';
import 'router.dart';

const bool skipAuthForDev = false;

final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
  region: 'europe-west2',
);
final FirebaseFirestore firestore = FirebaseFirestore.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🧩 Firebase core setup (must come first)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🛎 Local + FCM notifications (after Firebase init)
  try {
    await NotificationService.init();
  } catch (e, stack) {
    debugPrint('⚠️ NotificationService init failed: $e');
    debugPrint(stack.toString());
  }

  // 🔐 App Check (dev mode for now)
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // 🛒 RevenueCat
  await Purchases.configure(
    PurchasesConfiguration('appl_oqbgqmtmctjzzERpEkswCejmukh'),
  );

  // 🔄 Sync entitlement info from RevenueCat to Firestore
  await UserSessionService.restoreAndSyncEntitlement();

  // 🐝 Hive local storage
  await Hive.initFlutter();
  Hive.registerAdapter(RecipeCardModelAdapter());
  Hive.registerAdapter(CategoryModelAdapter());

  try {
    await Hive.openBox<RecipeCardModel>('recipes');
    await Hive.openBox<CategoryModel>('categories');
    await Hive.openBox<String>('customCategories');
  } catch (e, stack) {
    debugPrint('❌ Failed to open Hive box: $e');
    debugPrint(stack.toString());
  }

  // ⚙️ Load local preferences
  await UserPreferencesService.init();

  // 🏁 Start the app
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()..loadTheme()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()..loadScale()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()..init()),
      ],
      child: buildAppWithRouter(),
    ),
  );
}
