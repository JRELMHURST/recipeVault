// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/z_main_widgets/local_flags.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/theme_notifier.dart';
import 'core/text_scale_notifier.dart';
import 'model/recipe_card_model.dart';
import 'model/category_model.dart';
import 'services/user_preference_service.dart';
import 'revcat_paywall/services/subscription_service.dart';
import 'revcat_paywall/services/access_manager.dart';
import 'router.dart';

const bool skipAuthForDev = true; // 🔧 Flip to false before release

final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
  region: 'europe-west2',
);
final FirebaseFirestore firestore = FirebaseFirestore.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Purchases.configure(
    PurchasesConfiguration("appl_oqbgqmtmctjzzERpEkswCejmukh"),
  );

  await Hive.initFlutter();
  Hive.registerAdapter(RecipeCardModelAdapter());
  Hive.registerAdapter(CategoryModelAdapter());

  // 🔧 DEV RESET BLOCK — remove when stable
  if (skipAuthForDev) {
    await FirebaseAuth.instance.signOut();
    await Hive.deleteBoxFromDisk('recipes');
    await Hive.deleteBoxFromDisk('categories');
    await Hive.deleteBoxFromDisk('customCategories');
    await LocalFlags.init();
    await LocalFlags.reset();
    debugPrint('✅ Signed out + Cleared Hive + Cleared SharedPreferences');
  }

  await Hive.openBox<RecipeCardModel>('recipes');
  await Hive.openBox<CategoryModel>('categories');
  await Hive.openBox<String>('customCategories');

  await UserPreferencesService.init();
  await SubscriptionService().init();
  await AccessManager.initialise();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()..loadTheme()),
        ChangeNotifierProvider(create: (_) => TextScaleNotifier()..loadScale()),
      ],
      child: const RecipeVaultApp(),
    ),
  );
}

class RecipeVaultApp extends StatelessWidget {
  const RecipeVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final textScaleNotifier = Provider.of<TextScaleNotifier>(context);

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScaleNotifier.scaleFactor)),
      child: MaterialApp.router(
        title: 'RecipeVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeNotifier.themeMode,
        routerConfig: buildRouter(),
      ),
    );
  }
}
