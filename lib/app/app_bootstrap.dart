// lib/app_bootstrap.dart
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:recipe_vault/app/firebase_options.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/data/models/category_model.dart';
import 'package:recipe_vault/data/services/category_service.dart';
import 'package:recipe_vault/data/services/notification_service.dart';
import 'package:recipe_vault/data/services/user_preference_service.dart';

class AppBootstrap {
  static bool _isReady = false;

  /// Cloud Functions / Firestore (shared singletons)
  static final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'europe-west2',
  );
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Call once at app start (idempotent).
  static Future<void> ensureReady() async {
    if (_isReady) return;

    // 1) Firebase Init
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ Firebase initialization failed: $e');
        print(stack);
      }
      return; // nothing else will work
    }

    // (Optional) Debug emulators — uncomment while developing backends.
    // if (kDebugMode) {
    //   functions.useFunctionsEmulator('localhost', 5001);
    //   FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    // }

    // 2) App Check
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kReleaseMode
              ? AndroidProvider.playIntegrity
              : AndroidProvider.debug,
          appleProvider: kReleaseMode
              ? AppleProvider.appAttest
              : AppleProvider.debug,
        );
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ Firebase App Check failed: $e');
        print(stack);
      }
    }

    // 3) RevenueCat Setup
    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);

      // Use platform-specific keys if you have them (recommended).
      // Replace with your own keys; your original single key is left as a fallback.
      final rcConfig = PurchasesConfiguration(
        Platform.isIOS
            ? 'appl_oqbgqmtmctjzzERpEkswCejmukh' // iOS public SDK key
            : 'goog_oqbgqmtmctjzzERpEkswCejmukh', // ANDROID key (example)
      );

      await Purchases.configure(rcConfig);
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ RevenueCat configure failed: $e');
        print(stack);
      }
      // Don’t return; access control can fall back to Firestore tier.
    }

    // 4) Notifications (permissions/tokens handled inside)
    try {
      await NotificationService.init();
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ NotificationService init failed: $e');
        print(stack);
      }
    }

    // 5) Hive init + adapters + (optional) legacy migration
    bool hasLocalData = false;
    try {
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(RecipeCardModelAdapter()); // keep your typeIds
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CategoryModelAdapter());
      }

      // Detect legacy boxes (best-effort; don’t block startup)
      try {
        final legacyRecipes = await Hive.boxExists('recipes');
        final legacyCategories = await Hive.boxExists('categories');
        hasLocalData = legacyRecipes || legacyCategories;
      } catch (_) {}

      // Migrate legacy 'categories' box string items -> CategoryModel JSON, if present.
      try {
        if (await Hive.boxExists('categories')) {
          final catBox = await Hive.openBox('categories');
          final legacyKeys = catBox.keys
              .where((k) => catBox.get(k) is String)
              .toList();
          for (final key in legacyKeys) {
            final old = catBox.get(key) as String;
            await catBox.put(key, CategoryModel(id: key.toString(), name: old));
            if (kDebugMode) {
              print('🔁 Migrated legacy category "$old" → CategoryModel');
            }
          }
          await catBox.close();
        }
      } catch (e, stack) {
        if (kDebugMode) {
          print('⚠️ Legacy category migration failed: $e');
          print(stack);
        }
      }

      // Bootstrap category storage (opens per-user boxes lazily later).
      await CategoryService.init();
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ Hive setup failed: $e');
        print(stack);
      }
    }

    // 6) User preferences (opens per-user prefs lazily later too)
    try {
      await UserPreferencesService.init();
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ UserPreferencesService init failed: $e');
        print(stack);
      }
    }

    // 7) New-user heuristic (non-blocking; used for onboarding hints only)
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

      await UserPreferencesService.setBool('is_new_user', isNew);
      if (kDebugMode) {
        print(
          isNew
              ? '🆕 New user detected — onboarding enabled'
              : 'ℹ️ Existing user — onboarding disabled',
        );
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ New-user heuristic failed: $e');
        print(stack);
      }
    }

    // 8) Dev auth logging (safe in prod, just chatty)
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
