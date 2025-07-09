// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'widgets/processing_overlay.dart';
import 'core/theme.dart';
import 'core/theme_notifier.dart';
import 'core/text_scale_notifier.dart';
import 'model/recipe_card_model.dart';
import 'model/category_model.dart';
import 'screens/welcome_screen.dart';
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
import 'services/category_service.dart';
import 'revcat_paywall/screens/subscription_success_screen.dart';
import 'revcat_paywall/screens/upgrade_blocked_screen.dart';
import 'revcat_paywall/screens/paywall_screen.dart';
import 'revcat_paywall/services/subscription_service.dart';
import 'revcat_paywall/services/access_manager.dart';
import 'revcat_paywall/services/subscription_manager.dart';

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

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const RedirectDecider()),
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
      path: '/processing',
      builder: (context, state) {
        final List<File>? imageFiles = state.extra as List<File>?;
        return ProcessingOverlayScreen(imageFiles: imageFiles);
      },
    ),
    GoRoute(
      path: '/upgrade-success',
      builder: (context, state) => const SubscriptionSuccessScreen(),
    ),
    GoRoute(
      path: '/upgrade-blocked',
      builder: (context, state) => const UpgradeBlockedScreen(),
    ),
  ],
);

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
        routerConfig: _router,
      ),
    );
  }
}

class RedirectDecider extends StatefulWidget {
  const RedirectDecider({super.key});
  @override
  State<RedirectDecider> createState() => _RedirectDeciderState();
}

class _RedirectDeciderState extends State<RedirectDecider> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleRedirect();
    });
  }

  Future<void> _handleRedirect() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;

    if (!SubscriptionManager().hasAccess) {
      context.go('/pricing');
    } else if (user == null) {
      context.go('/login');
    } else if (!hasSeenWelcome) {
      context.go('/welcome');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class ProcessingOverlayScreen extends StatelessWidget {
  final List<File>? imageFiles;
  const ProcessingOverlayScreen({super.key, this.imageFiles});

  @override
  Widget build(BuildContext context) {
    if (imageFiles != null && imageFiles!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ProcessingOverlay.show(context, imageFiles!);
      });
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
