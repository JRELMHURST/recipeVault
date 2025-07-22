// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

// Core & Services
import 'firebase_options.dart';
import 'core/theme_notifier.dart';
import 'core/text_scale_notifier.dart';
import 'services/category_service.dart';
import 'services/notification_service.dart';
import 'services/user_preference_service.dart';

// Models
import 'model/recipe_card_model.dart';
import 'model/category_model.dart';

// Subscription
import 'rev_cat/subscription_service.dart';

// App Boot
import 'start_up_gate.dart';
import 'router.dart'; // ✅ ensures buildAppWithRouter() is available

// Firebase globals
final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
  region: 'europe-west2',
);
final FirebaseFirestore firestore = FirebaseFirestore.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🧩 Firebase init
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔐 App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // 🛒 RevenueCat config
  try {
    await Purchases.configure(
      PurchasesConfiguration('appl_oqbgqmtmctjzzERpEkswCejmukh'),
    );
  } catch (e, stack) {
    debugPrint('❌ RevenueCat config failed: $e');
    debugPrint(stack.toString());
  }

  // 🔔 Notifications
  try {
    await NotificationService.init();
  } catch (e, stack) {
    debugPrint('⚠️ NotificationService init failed: $e');
    debugPrint(stack.toString());
  }

  // 🐝 Hive setup
  await Hive.initFlutter();
  Hive.registerAdapter(RecipeCardModelAdapter());
  Hive.registerAdapter(CategoryModelAdapter());

  try {
    await Hive.openBox<RecipeCardModel>('recipes');
    await Hive.openBox<CategoryModel>('categories');
    await CategoryService.init(); // opens custom + hidden boxes
  } catch (e, stack) {
    debugPrint('❌ Hive box opening failed: $e');
    debugPrint(stack.toString());
  }

  // ⚙️ Local user prefs
  await UserPreferencesService.init();

  // 🚀 Launch app
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()..loadTheme()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()..loadScale()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
      ],
      child: StartupGate(child: buildAppWithRouter()),
    ),
  );
}
