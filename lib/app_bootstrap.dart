import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'firebase_options.dart';
import 'model/recipe_card_model.dart';
import 'model/category_model.dart';
import 'services/category_service.dart';
import 'services/notification_service.dart';
import 'services/user_preference_service.dart';
import 'services/user_session_service.dart';
import 'services/view_mode.dart';

class AppBootstrap {
  static bool _isReady = false;

  /// Firebase globals – exposed if needed in-app
  static final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'europe-west2',
  );
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<void> ensureReady() async {
    if (_isReady) return;

    // 🔌 Firebase Init
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

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
      if (kDebugMode) {
        print('❌ RevenueCat config failed: $e');
        print(stack);
      }
    }

    // 🔔 Push Notifications
    try {
      await NotificationService.init();
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ NotificationService init failed: $e');
        print(stack);
      }
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
        if (kDebugMode) {
          print('🔁 Migrated legacy category "$oldValue" to CategoryModel');
        }
      }

      await CategoryService.init();
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ Hive setup failed: $e');
        print(stack);
      }
    }

    // 👤 Load and sync session (auth, tier, entitlement, onboarding)
    await UserSessionService.init();

    // ⚙️ Load local preferences (only if signed in)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await UserPreferencesService.init();
    }

    // 👤 If signed in, load preferences and view mode
    if (uid != null) {
      try {
        await UserPreferencesService.init();
        final savedViewMode = await ViewModeService.getViewMode();
        if (savedViewMode == ViewMode.list) {
          await ViewModeService.setViewMode(ViewMode.grid);
        }
      } catch (e, stack) {
        if (kDebugMode) {
          print('⚠️ Failed to load user preferences or view mode: $e');
          print(stack);
        }
      }
    }

    _isReady = true;
  }
}
