// lib/app/app_bootstrap.dart
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

import 'package:recipe_vault/billing/subscription_service.dart';

class AppBootstrap {
  AppBootstrap._();

  // Exposed services
  static final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'europe-west2',
  );
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // ── Readiness signalling for the router ──────────────────────────────
  static final ValueNotifier<bool> _ready = ValueNotifier<bool>(false);
  static ValueListenable<bool> get readyListenable => _ready;
  static bool get isReady => _ready.value;

  // One-shot timeout so the router can stop showing /boot after a while
  static const Duration _bootTimeout = Duration(seconds: 8);
  static final ValueNotifier<bool> _timeoutReached = ValueNotifier<bool>(false);
  static ValueListenable<bool> get timeoutListenable => _timeoutReached;
  static bool get timeoutReached => _timeoutReached.value;

  static bool _initialised = false;

  /// Call once at app start (before runApp).
  static Future<void> ensureReady() async {
    if (_initialised) return;
    _initialised = true;

    // Fire a one-shot signal at timeout so GoRouter re-runs redirects
    Future<void>.delayed(_bootTimeout).then((_) {
      if (!_timeoutReached.value) _timeoutReached.value = true;
    });

    // 1) Firebase Core
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, st) {
      debugPrint('❌ BOOT: Firebase init failed: $e');
      debugPrintStack(stackTrace: st);
      _ready.value = true; // let the router render an error/alternative
      return;
    }

    // 2) App Check
    try {
      if (kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          webProvider: kReleaseMode
              ? ReCaptchaV3Provider('YOUR_RECAPTCHA_SITE_KEY')
              : ReCaptchaV3Provider('debug'),
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
      debugPrint('⚠️ BOOT: App Check failed: $e');
      debugPrintStack(stackTrace: st);
    }

    // 3) RevenueCat — only configure on supported platforms
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
        final cfg = PurchasesConfiguration(
          Platform.isIOS
              ? 'appl_oqbgqmtmctjzzERpEkswCejmukh'
              : 'goog_oqbgqmtmctjzzERpEkswCejmukh',
        );
        await Purchases.configure(cfg);
      } else {
        debugPrint('ℹ️ BOOT: RevenueCat not configured (unsupported platform)');
      }
    } catch (e, st) {
      debugPrint('❌ BOOT: RevenueCat configure failed: $e');
      debugPrintStack(stackTrace: st);
    }

    // 4) Notifications
    try {
      await NotificationService.init();
    } catch (e, st) {
      debugPrint('⚠️ BOOT: NotificationService init failed: $e');
      debugPrintStack(stackTrace: st);
    }

    // 5) Hive + adapters (+ optional legacy migration)
    try {
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(RecipeCardModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CategoryModelAdapter());
      }

      // Optional legacy categories migration
      try {
        if (await Hive.boxExists('categories')) {
          final catBox = await Hive.openBox('categories');
          final legacyKeys = catBox.keys
              .where((k) => catBox.get(k) is String)
              .toList();
          for (final key in legacyKeys) {
            final old = catBox.get(key) as String;
            await catBox.put(key, CategoryModel(id: key.toString(), name: old));
            debugPrint(
              '🔁 BOOT: Migrated legacy category "$old" → CategoryModel',
            );
          }
          await catBox.close();
        }
      } catch (e, st) {
        debugPrint('⚠️ BOOT: Legacy category migration failed: $e');
        debugPrintStack(stackTrace: st);
      }

      await CategoryService.init();
      await UserPreferencesService.init();
    } catch (e, st) {
      debugPrint('❌ BOOT: Hive core setup failed: $e');
      debugPrintStack(stackTrace: st);
    }

    // 6) Keep per-user services + RC AppUserID in lockstep with Auth
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      debugPrint(
        user == null
            ? '🧍 BOOT: FirebaseAuth → No user signed in'
            : '✅ BOOT: FirebaseAuth → Signed in uid=${user.uid}',
      );

      try {
        await CategoryService.onAuthChanged(user?.uid);
      } catch (e, st) {
        debugPrint('⚠️ BOOT: CategoryService.onAuthChanged failed: $e');
        debugPrintStack(stackTrace: st);
      }
      try {
        await UserPreferencesService.onAuthChanged(user?.uid);
      } catch (e, st) {
        debugPrint('⚠️ BOOT: UserPreferencesService.onAuthChanged failed: $e');
        debugPrintStack(stackTrace: st);
      }
      try {
        await SubscriptionService().setAppUserId(user?.uid);
      } catch (e, st) {
        debugPrint('⚠️ BOOT: SubscriptionService.setAppUserId failed: $e');
        debugPrintStack(stackTrace: st);
      }
    });

    // Immediately sync current auth state (avoid waiting for first tick)
    final initialUser = FirebaseAuth.instance.currentUser;
    try {
      await CategoryService.onAuthChanged(initialUser?.uid);
      await UserPreferencesService.onAuthChanged(initialUser?.uid);
      await SubscriptionService().setAppUserId(initialUser?.uid);
    } catch (e, st) {
      debugPrint('⚠️ BOOT: Initial auth sync failed: $e');
      debugPrintStack(stackTrace: st);
    }

    // Core bootstrap finished → allow router to proceed
    _ready.value = true;
  }
}
