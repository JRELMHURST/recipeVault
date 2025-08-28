// lib/app/app_bootstrap.dart
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/data/models/category_model.dart';
import 'package:recipe_vault/data/services/category_service.dart';
import 'package:recipe_vault/data/services/notification_service.dart';
import 'package:recipe_vault/data/services/user_preference_service.dart';
import 'package:recipe_vault/billing/subscription/subscription_service.dart';

class AppBootstrap {
  AppBootstrap._();

  // Exposed Firebase services (Firebase is initialized in main.dart)
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

  // Prevent RevenueCat from being configured twice
  static bool _rcConfigured = false;

  /// Call once at app start (before runApp).
  static Future<void> ensureReady() async {
    if (_initialised) return;
    _initialised = true;

    // Fire a one-shot signal at timeout so GoRouter re-runs redirects
    Future<void>.delayed(_bootTimeout).then((_) {
      if (!_timeoutReached.value) _timeoutReached.value = true;
    });

    // 1) RevenueCat — only configure once, on supported platforms (Android/iOS only)
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        if (!_rcConfigured) {
          if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);

          // Prefer passing keys via --dart-define for security.
          final iosKey = const String.fromEnvironment(
            'RC_API_KEY_IOS',
            defaultValue: 'appl_oqbgqmtmctjzzERpEkswCejmukh',
          );
          final androidKey = const String.fromEnvironment(
            'RC_API_KEY_ANDROID',
            defaultValue: 'goog_oqbgqmtmctjzzERpEkswCejmukh',
          );

          final cfg = PurchasesConfiguration(
            Platform.isIOS ? iosKey : androidKey,
          );
          await Purchases.configure(cfg);
          _rcConfigured = true;
          debugPrint('✅ BOOT: RevenueCat configured');
        } else {
          debugPrint('ℹ️ BOOT: RevenueCat already configured, skipping');
        }
      } else {
        debugPrint('ℹ️ BOOT: RevenueCat not configured (non-mobile platform)');
      }
    } catch (e, st) {
      debugPrint('❌ BOOT: RevenueCat configure failed: $e');
      debugPrintStack(stackTrace: st);
    }

    // 2) Notifications
    try {
      await NotificationService.init();
    } catch (e, st) {
      debugPrint('⚠️ BOOT: NotificationService init failed: $e');
      debugPrintStack(stackTrace: st);
    }

    // 3) Hive + adapters (+ optional legacy migration)
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

    // 4) Keep per-user services + RC AppUserID in lockstep with Auth
    //    Use a single, de-duplicated listener (no immediate “initial sync”).
    FirebaseAuth.instance
        .authStateChanges()
        .distinct((prev, next) => prev?.uid == next?.uid) // de-dupe by UID
        .listen((user) async {
          debugPrint(
            user == null
                ? '🧍 BOOT: FirebaseAuth → No user signed in'
                : '✅ BOOT: FirebaseAuth → Signed in uid=${user.uid}',
          );

          final uid = user?.uid;

          try {
            await CategoryService.onAuthChanged(uid);
          } catch (e, st) {
            debugPrint('⚠️ BOOT: CategoryService.onAuthChanged failed: $e');
            debugPrintStack(stackTrace: st);
          }
          try {
            await UserPreferencesService.onAuthChanged(uid);
          } catch (e, st) {
            debugPrint(
              '⚠️ BOOT: UserPreferencesService.onAuthChanged failed: $e',
            );
            debugPrintStack(stackTrace: st);
          }
          try {
            await SubscriptionService().setAppUserId(uid);
            await SubscriptionService().refresh(); // ✅ Add this
          } catch (e, st) {
            debugPrint('⚠️ BOOT: SubscriptionService failed: $e');
            debugPrintStack(stackTrace: st);
          }
        });

    // 5) Core bootstrap finished → allow router to proceed
    _ready.value = true;
  }
}
