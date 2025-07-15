// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/theme_notifier.dart';
import 'core/text_scale_notifier.dart';
import 'model/recipe_card_model.dart';
import 'model/category_model.dart';
import 'services/user_preference_service.dart';
import 'rev_cat/subscription_service.dart';
import 'services/user_session_service.dart'; // ✅ Newly added
import 'router.dart'; // This will now provide Navigator 1.0 route definitions

const bool skipAuthForDev = false;

final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
  region: 'europe-west2',
);
final FirebaseFirestore firestore = FirebaseFirestore.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  await Purchases.configure(
    PurchasesConfiguration('appl_oqbgqmtmctjzzERpEkswCejmukh'),
  );

  // ✅ Sync RevenueCat entitlement to Firestore
  await UserSessionService.syncRevenueCatEntitlement();

  await Hive.initFlutter();
  Hive.registerAdapter(RecipeCardModelAdapter());
  Hive.registerAdapter(CategoryModelAdapter());

  try {
    await Hive.openBox<RecipeCardModel>('recipes');
    await Hive.openBox<CategoryModel>('categories');
    await Hive.openBox<String>('customCategories');
  } catch (e, stack) {
    debugPrint('❌ Failed to open Hive box: \$e');
    debugPrint(stack.toString());
  }

  await UserPreferencesService.init();

  final initialRoute = _getInitialRouteFromDeepLink();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()..loadTheme()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()..loadScale()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()..refresh()),
      ],
      child: RecipeVaultApp(initialRoute: initialRoute),
    ),
  );
}

/// Detects launch route from universal link like https://recipevault.app/shared/abc123
String _getInitialRouteFromDeepLink() {
  final uri = Uri.base;
  if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shared') {
    final id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
    if (id != null) return '/shared/\$id';
  }
  return '/'; // fallback
}

class RecipeVaultApp extends StatelessWidget {
  final String initialRoute;

  const RecipeVaultApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final textScaleNotifier = Provider.of<TextScaleNotifier>(context);

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScaleNotifier.scaleFactor)),
      child: MaterialApp(
        title: 'RecipeVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeNotifier.themeMode,
        initialRoute: initialRoute, // ✅ Now defined properly
        onGenerateRoute: generateRoute,
      ),
    );
  }
}
