import 'dart:io' show Platform;

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
        print('❌ Firebase initialisation failed: $e');
        print(stack);
      }
      // Hard stop: nothing else works without Firebase.
      return;
    }

    // 2) Firebase App Check (only on mobile; debug providers here)
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
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
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      await Purchases.configure(
        PurchasesConfiguration('appl_oqbgqmtmctjzzERpEkswCejmukh'),
      );
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ RevenueCat config failed: $e');
        print(stack);
      }
      // Don’t return; AccessController will fall back to Firestore.
    }

    // 4) Push Notifications (tokens/permissions handled in your service)
    try {
      await NotificationService.init();
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ NotificationService init failed: $e');
        print(stack);
      }
    }

    // 5) Hive Init + Adapters + CategoryService bootstrap
    //    IMPORTANT: don’t open generic boxes here; services/screens open per-user boxes when needed.
    bool hasLocalData = false;
    try {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(
          RecipeCardModelAdapter(),
        ); // adjust typeIds as per your g.dart
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CategoryModelAdapter());
      }

      // Optional: detect legacy boxes without opening them.
      // Keep this best-effort so we don’t block startup.
      try {
        final legacyRecipes = await Hive.boxExists('recipes');
        final legacyCategories = await Hive.boxExists('categories');
        hasLocalData = legacyRecipes || legacyCategories;
      } catch (_) {}

      // Migrate legacy String categories to CategoryModel **only if the legacy box exists**.
      // (If you no longer ship those boxes, this will just noop.)
      try {
        if (await Hive.boxExists('categories')) {
          final catBox = await Hive.openBox('categories');
          final legacyKeys = catBox.keys
              .where((k) => catBox.get(k) is String)
              .toList();

          for (final key in legacyKeys) {
            final oldValue = catBox.get(key) as String;
            final migrated = CategoryModel(id: key.toString(), name: oldValue);
            await catBox.put(key, migrated);
            if (kDebugMode) {
              print('🔁 Migrated legacy category "$oldValue" to CategoryModel');
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

      // Initialise any static caches/indices your CategoryService needs.
      await CategoryService.init();
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ Hive setup failed: $e');
        print(stack);
      }
    }

    // 6) User preferences
    try {
      await UserPreferencesService.init();
    } catch (e, stack) {
      if (kDebugMode) {
        print('⚠️ Failed to initialise user preferences: $e');
        print(stack);
      }
    }

    // 7) New-user heuristic (non-blocking)
    //    We don’t *route* on this directly anymore (router handles access),
    //    but you might still use it for onboarding hints.
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
        print('⚠️ Failed to determine new user status: $e');
        print(stack);
      }
    }

    // 8) Dev auth logging (harmless in prod)
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
