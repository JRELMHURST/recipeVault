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

  /// Firebase & Cloud Functions globals
  static final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'europe-west2',
  );
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<void> ensureReady() async {
    if (_isReady) return;

    // 1️⃣ Firebase Init
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

    // 2️⃣ Firebase App Check
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

    // 3️⃣ RevenueCat Setup
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

    // 4️⃣ Push Notifications
    try {
      await NotificationService.init();
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ NotificationService init failed: $e');
        print(stack);
      }
    }

    // 5️⃣ Hive Init + Migrations
    bool hasLocalData = false;
    try {
      await Hive.initFlutter();
      Hive.registerAdapter(RecipeCardModelAdapter());
      Hive.registerAdapter(CategoryModelAdapter());

      final recipeBox = await Hive.openBox<RecipeCardModel>('recipes');
      final categoryBox = await Hive.openBox<CategoryModel>('categories');

      hasLocalData = recipeBox.isNotEmpty || categoryBox.isNotEmpty;

      // Migrate legacy String categories to CategoryModel
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

    // 6️⃣ User preferences
    try {
      await UserPreferencesService.init();
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ Failed to initialise user preferences: $e');
        print(stack);
      }
    }

    // 7️⃣ Check new user status (Firestore + Hive)
    try {
      final user = FirebaseAuth.instance.currentUser;
      bool isNew = false;

      if (user != null) {
        final doc = await firestore.collection('users').doc(user.uid).get();
        if (!doc.exists && !hasLocalData) {
          isNew = true;
        }
      } else if (!hasLocalData) {
        isNew = true;
      }

      if (isNew) {
        await UserPreferencesService.setBool('is_new_user', true);
        if (kDebugMode) print('🆕 New user detected — onboarding enabled');
      } else {
        await UserPreferencesService.setBool('is_new_user', false);
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ Failed to determine new user status: $e');
        print(stack);
      }
    }

    // 8️⃣ Auth state logging (for dev)
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

    _isReady = true;
  }
}
