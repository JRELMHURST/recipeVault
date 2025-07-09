import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/settings/appearance_settings_screen.dart';

import 'app_router.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/accessibility.dart';
import 'model/recipe_card_model.dart';
import 'model/category_model.dart';
import 'services/user_preference_service.dart';
import 'services/category_service.dart';
import 'revcat_paywall/services/subscription_service.dart';
import 'revcat_paywall/services/access_manager.dart';

late final FirebaseFunctions functions;
final FirebaseFirestore firestore = FirebaseFirestore.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  functions = FirebaseFunctions.instanceFor(region: 'europe-west2');

  await Purchases.configure(
    PurchasesConfiguration("appl_oqbgqmtmctjzzERpEkswCejmukh"),
  );

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await Purchases.logIn(user.uid);
  }

  await Hive.initFlutter();
  Hive.registerAdapter(RecipeCardModelAdapter());
  Hive.registerAdapter(CategoryModelAdapter());
  await Hive.openBox<RecipeCardModel>('recipes');
  await Hive.openBox<CategoryModel>('categories');
  await Hive.openBox<String>('customCategories');

  await UserPreferencesService.init();

  if (user != null) {
    await CategoryService.syncFromFirestore();
  }

  await SubscriptionService().init();
  await AccessManager.initialise();

  final themeNotifier = ThemeNotifier();
  await themeNotifier.loadTheme();

  runApp(
    ChangeNotifierProvider(
      create: (_) => themeNotifier,
      child: Consumer<ThemeNotifier>(
        builder: (context, notifier, _) =>
            RecipeVaultApp(themeNotifier: notifier),
      ),
    ),
  );
}

class RecipeVaultApp extends StatelessWidget {
  final ThemeNotifier themeNotifier;
  const RecipeVaultApp({super.key, required this.themeNotifier});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          Accessibility.constrainedTextScale(context),
        ),
      ),
      child: MaterialApp.router(
        title: 'RecipeVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeNotifier.themeMode,
        routerConfig: createAppRouter(themeNotifier),
      ),
    );
  }
}
