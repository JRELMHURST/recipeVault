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

  static final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'europe-west2',
  );
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static final ValueNotifier<bool> _ready = ValueNotifier<bool>(false);
  static ValueListenable<bool> get readyListenable => _ready;
  static bool get isReady => _ready.value;

  static const Duration _bootTimeout = Duration(seconds: 8);
  static final ValueNotifier<bool> _timeoutReached = ValueNotifier<bool>(false);
  static ValueListenable<bool> get timeoutListenable => _timeoutReached;
  static bool get timeoutReached => _timeoutReached.value;

  static bool _initialised = false;
  static bool _rcConfigured = false;
  static bool _hasSetReady = false;

  static Future<void> ensureReady() async {
    if (_initialised) return;
    _initialised = true;

    Future<void>.delayed(_bootTimeout).then((_) {
      if (!_timeoutReached.value) _timeoutReached.value = true;
    });

    try {
      if (Platform.isIOS || Platform.isAndroid) {
        if (!_rcConfigured) {
          if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);

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
          debugPrint('✅ BOOT: RevenueCat configured successfully');
        } else {
          debugPrint('ℹ️ BOOT: RevenueCat already configured — skipping setup');
        }
      } else {
        debugPrint('ℹ️ BOOT: RevenueCat not configured (non-mobile platform)');
      }
    } catch (e, st) {
      debugPrint(
        '❌ BOOT ERROR: Failed to configure RevenueCat (in-app purchases). Error: $e',
      );
      debugPrintStack(stackTrace: st);
    }

    try {
      await NotificationService.init();
    } catch (e, st) {
      debugPrint(
        '⚠️ BOOT WARNING: NotificationService failed to initialize. Some features may be unavailable. Error: $e',
      );
      debugPrintStack(stackTrace: st);
    }

    try {
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(RecipeCardModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CategoryModelAdapter());
      }

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
        debugPrint(
          '⚠️ BOOT WARNING: Failed to migrate legacy category entries. Old categories may not appear correctly. Error: $e',
        );
        debugPrintStack(stackTrace: st);
      }

      await CategoryService.init();
      await UserPreferencesService.init();
    } catch (e, st) {
      debugPrint(
        '❌ BOOT ERROR: Failed to initialise local data storage (Hive). App may not function as expected. Error: $e',
      );
      debugPrintStack(stackTrace: st);
    }

    FirebaseAuth.instance
        .authStateChanges()
        .distinct((prev, next) => prev?.uid == next?.uid)
        .listen((user) async {
          debugPrint(
            user == null
                ? '👤 BOOT: No user currently signed in. Limited functionality available.'
                : '✅ BOOT: Signed in as user → ${user.uid}',
          );

          final uid = user?.uid;

          try {
            await CategoryService.onAuthChanged(uid);
          } catch (e, st) {
            debugPrint(
              '⚠️ BOOT WARNING: Failed to update category preferences. Error: $e',
            );
            debugPrintStack(stackTrace: st);
          }

          try {
            await UserPreferencesService.onAuthChanged(uid);
          } catch (e, st) {
            debugPrint(
              '⚠️ BOOT WARNING: Failed to load user preferences. Error: $e',
            );
            debugPrintStack(stackTrace: st);
          }

          try {
            final subs = SubscriptionService();
            await subs.setAppUserId(uid);
            await subs.refresh();
          } catch (e, st) {
            debugPrint(
              '⚠️ BOOT WARNING: Failed to initialise subscription status. Error: $e',
            );
            debugPrintStack(stackTrace: st);
          }

          if (!_hasSetReady) {
            _hasSetReady = true;
            _ready.value = true;
            debugPrint(
              '✅ BOOT COMPLETE: AppBootstrap marked ready. All critical services initialised.',
            );
          }
        });
  }
}
