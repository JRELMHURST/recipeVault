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

import 'package:recipe_vault/firebase_options.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/data/models/category_model.dart';
import 'package:recipe_vault/data/services/category_service.dart';
import 'package:recipe_vault/data/services/notification_service.dart';
import 'package:recipe_vault/data/services/user_preference_service.dart';
// ✅ RC <-> Firebase UID binding + tier preloading
import 'package:recipe_vault/billing/subscription_service.dart';

class AppBootstrap {
  AppBootstrap._();
  static bool _isReady = false;

  static final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'europe-west2',
  );
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Call once at app start (idempotent).
  static Future<void> ensureReady() async {
    if (_isReady) return;

    /* 1) Firebase core */
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ Firebase initialization failed: $e');
        debugPrintStack(stackTrace: st);
      }
      return; // nothing else will work
    }

    // Optional emulators:
    // if (kDebugMode) {
    //   functions.useFunctionsEmulator('localhost', 5001);
    //   firestore.useFirestoreEmulator('localhost', 8080);
    // }

    /* 2) App Check */
    try {
      if (kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          webProvider: kReleaseMode
              ? ReCaptchaV3Provider('YOUR_RECAPTCHA_SITE_KEY')
              : ReCaptchaV3Provider('** debug **'),
        );
      } else if (Platform.isAndroid || Platform.isIOS) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kReleaseMode
              ? AndroidProvider.playIntegrity
              : AndroidProvider.debug,
          appleProvider: kReleaseMode
              ? AppleProvider.deviceCheck
              : AppleProvider.debug,
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('⚠️ App Check failed: $e');
        debugPrintStack(stackTrace: st);
      }
    }

    /* 3) RevenueCat (SDK configure only) */
    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
      final cfg = PurchasesConfiguration(
        Platform.isIOS
            ? 'appl_oqbgqmtmctjzzERpEkswCejmukh'
            : 'goog_oqbgqmtmctjzzERpEkswCejmukh',
      );
      await Purchases.configure(cfg);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ RevenueCat configure failed: $e');
        debugPrintStack(stackTrace: st);
      }
    }

    /* 4) Notifications */
    try {
      await NotificationService.init();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('⚠️ NotificationService init failed: $e');
        debugPrintStack(stackTrace: st);
      }
    }

    /* 5) Hive core + adapters (no per-user boxes yet) */

    try {
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(RecipeCardModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CategoryModelAdapter());
      }

      // Legacy presence heuristic
      try {} catch (_) {}

      // Optional legacy migration
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
              debugPrint('🔁 Migrated legacy category "$old" → CategoryModel');
            }
          }
          await catBox.close();
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('⚠️ Legacy category migration failed: $e');
          debugPrintStack(stackTrace: st);
        }
      }

      await CategoryService.init();
      await UserPreferencesService.init();

      // ✅ Prime subscription service so UI can react immediately
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ Hive core setup failed: $e');
        debugPrintStack(stackTrace: st);
      }
    }

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (kDebugMode) {
        debugPrint(
          user == null
              ? '🧍 FirebaseAuth: No user signed in'
              : '✅ FirebaseAuth: Signed in uid=${user.uid}',
        );
      }

      // Per-user services
      try {
        await CategoryService.onAuthChanged(user?.uid);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('⚠️ CategoryService.onAuthChanged failed: $e');
          debugPrintStack(stackTrace: st);
        }
      }
      try {
        await UserPreferencesService.onAuthChanged(user?.uid);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('⚠️ UserPreferencesService.onAuthChanged failed: $e');
          debugPrintStack(stackTrace: st);
        }
      }

      // ✅ Keep RevenueCat AppUserID in lockstep with Firebase UID
      try {
        await SubscriptionService().setAppUserId(user?.uid);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('⚠️ SubscriptionService.setAppUserId failed: $e');
          debugPrintStack(stackTrace: st);
        }
      }
    });

    _isReady = true;
  }
}
