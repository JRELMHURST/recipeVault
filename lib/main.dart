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
import 'router.dart';
import 'screens/recipe_vault/recipe_vault_controller.dart';

// Firebase globals
final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
  region: 'europe-west2',
);
final FirebaseFirestore firestore = FirebaseFirestore.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔌 Firebase Init
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔐 Firebase App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // 🛒 RevenueCat Setup
  try {
    await Purchases.configure(
      PurchasesConfiguration('appl_oqbgqmtmctjzzERpEkswCejmukh'),
    );
  } catch (e, stack) {
    debugPrint('❌ RevenueCat config failed: $e');
    debugPrint(stack.toString());
  }

  // 🔔 Push Notifications
  try {
    await NotificationService.init();
  } catch (e, stack) {
    debugPrint('⚠️ NotificationService init failed: $e');
    debugPrint(stack.toString());
  }

  // 🐝 Hive Init
  await Hive.initFlutter();
  Hive.registerAdapter(RecipeCardModelAdapter());
  Hive.registerAdapter(CategoryModelAdapter());

  try {
    await Hive.openBox<RecipeCardModel>('recipes');
    final categoryBox = await Hive.openBox<CategoryModel>('categories');

    // 🔁 Migrate legacy string categories to CategoryModel
    final legacyKeys = categoryBox.keys
        .where((k) => categoryBox.get(k) is String)
        .toList();

    for (final key in legacyKeys) {
      final oldValue = categoryBox.get(key) as String;
      final migrated = CategoryModel(id: key.toString(), name: oldValue);
      await categoryBox.put(key, migrated);
      debugPrint('🔁 Migrated legacy category "$oldValue" to CategoryModel');
    }

    // 🧠 Open additional category boxes
    await CategoryService.init();
  } catch (e, stack) {
    debugPrint('❌ Hive setup failed: $e');
    debugPrint(stack.toString());
  }

  // ⚙️ Load local preferences
  await UserPreferencesService.init();

  // 🚀 Launch App with Providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()..loadTheme()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()..loadScale()),
        ChangeNotifierProvider<SubscriptionService>.value(
          value: SubscriptionService(),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final controller = RecipeVaultController();
            controller.initialise();
            return controller;
          },
        ),
      ],
      child: StartupGate(child: buildAppWithRouter()),
    ),
  );
}
