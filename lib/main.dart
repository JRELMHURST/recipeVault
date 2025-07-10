// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/launch_gate_screen.dart';
import 'package:recipe_vault/z_main_idgets/user_session_service.dart';

import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/theme_notifier.dart';
import 'core/text_scale_notifier.dart';
import 'model/recipe_card_model.dart';
import 'model/category_model.dart';
import 'screens/welcome_screen/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/results_screen.dart';
import 'login/login_screen.dart';
import 'login/register_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/acount_settings/account_settings_screen.dart';
import 'settings/acount_settings/change_password.dart';
import 'settings/appearance_settings_screen.dart';
import 'settings/notifications_settings_screen.dart';
import 'settings/subscription_settings_screen.dart';
import 'settings/about_screen.dart';
import 'settings/storage_sync_screen.dart';
import 'services/user_preference_service.dart';
import 'revcat_paywall/screens/subscription_success_screen.dart';
import 'revcat_paywall/screens/upgrade_blocked_screen.dart';
import 'revcat_paywall/screens/paywall_screen.dart';
import 'revcat_paywall/services/subscription_service.dart';
import 'revcat_paywall/services/access_manager.dart';

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
  await Hive.openBox<RecipeCardModel>('recipes');
  await Hive.openBox<CategoryModel>('categories');
  await Hive.openBox<String>('customCategories');

  await UserPreferencesService.init();
  await SubscriptionService().init();
  await SubscriptionService().refresh();
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

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        final user = snapshot.data;

        // 🖁 Handle login, logout, sync
        UserSessionService.handleUserChange(user);

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScaleNotifier.scaleFactor),
          ),
          child: MaterialApp.router(
            title: 'RecipeVault',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeNotifier.themeMode,
            routerConfig: _buildRouter(),
          ),
        );
      },
    );
  }
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    redirect: null, // <-- Explicitly disables redirect logic (important!)
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LaunchGateScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/pricing',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/account',
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/account/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (context, state) => AppearanceSettingsScreen(
          themeNotifier: Provider.of<ThemeNotifier>(context, listen: false),
          textScaleNotifier: Provider.of<TextScaleNotifier>(
            context,
            listen: false,
          ),
        ),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationsSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/subscription',
        builder: (context, state) => const SubscriptionSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (context, state) => const AboutSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/storage-sync',
        builder: (context, state) => const StorageSyncScreen(),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) => const ResultsScreen(),
      ),
      GoRoute(
        path: '/upgrade-success',
        builder: (context, state) => const SubscriptionSuccessScreen(),
      ),
      GoRoute(
        path: '/upgrade-blocked',
        builder: (context, state) => const UpgradeBlockedScreen(),
      ),

      // ✅ Added fallback error screen
      GoRoute(
        path: '/error',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text(
              'Something went wrong.\nPlease try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ],
  );
}
