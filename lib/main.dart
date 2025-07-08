// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'firebase_options.dart';
import 'widgets/processing_overlay.dart';
import 'core/theme.dart';
import 'core/accessibility.dart';
import 'model/recipe_card_model.dart';
import 'model/category_model.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/results_screen.dart';
import 'login/login_screen.dart';
import 'login/register_screen.dart';
import 'settings/settings_screen.dart';
import 'services/user_preference_service.dart';
import 'services/category_service.dart';
import 'revcat_paywall/screens/subscription_success_screen.dart';
import 'revcat_paywall/screens/upgrade_blocked_screen.dart';
import 'revcat_paywall/screens/paywall_screen.dart';
import 'revcat_paywall/services/subscription_service.dart';
import 'revcat_paywall/services/access_manager.dart';
import 'revcat_paywall/services/subscription_manager.dart';
import 'login/dev_testing_screen.dart';

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

  runApp(const RecipeVaultApp());
}

/// Routing configuration
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
    if (!kReleaseMode)
      GoRoute(
        path: '/dev-tools',
        builder: (context, state) => const DevTestingScreen(),
      ),
  ],
);

/// Root app widget
class RecipeVaultApp extends StatelessWidget {
  const RecipeVaultApp({super.key});

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
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}

/// Determines which screen to show on app launch
class RedirectDecider extends StatefulWidget {
  const RedirectDecider({super.key});

  @override
  State<RedirectDecider> createState() => _RedirectDeciderState();
}

class _RedirectDeciderState extends State<RedirectDecider> {
  @override
  void initState() {
    super.initState();
    _handleRedirect();
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

/// Temporary screen wrapper for processing overlay
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
