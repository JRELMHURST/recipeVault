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

class AppBootstrap {
  static bool _isReady = false;

  /// Firebase globals – exposed if needed in-app
  static final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'europe-west2',
  );
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<void> ensureReady() async {
    if (_isReady) return;

    // 🔌 Firebase Init
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ Firebase initialisation failed: $e');
        print(stack);
      }
      return;
    }

    // 🔐 Firebase App Check
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ Firebase App Check failed: $e');
        print(stack);
      }
    }

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
    try {
      await Hive.initFlutter();
      Hive.registerAdapter(RecipeCardModelAdapter());
      Hive.registerAdapter(CategoryModelAdapter());

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

    // 🧠 User preferences
    try {
      await UserPreferencesService.init();
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ Failed to initialise user preferences: $e');
        print(stack);
      }
    }

    // 👤 Just log current auth state — do not initialise session here
    if (kDebugMode) {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user == null) {
          if (kDebugMode) {
            print('🧍 FirebaseAuth: No user signed in');
          }
        } else {
          if (kDebugMode) {
            print('✅ FirebaseAuth: User signed in with UID = ${user.uid}');
          }
        }
      });
    }

    // ✅ Do NOT call UserSessionService.init() here anymore
    // It is now safely handled in main.dart via authStateChanges()

    _isReady = true;
  }
}
