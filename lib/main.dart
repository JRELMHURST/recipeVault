import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recipe_vault/login/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'widgets/processing_overlay.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/results_screen.dart';
import 'login/login_screen.dart';
import 'settings/settings_screen.dart'; // ✅ Added
import 'core/theme.dart';
import 'core/accessibility.dart';
import 'model/recipe_card_model.dart';

/// Force welcome screen for dev/test
const bool kAlwaysShowWelcome = true;

/// Globally accessible Firebase Functions instance
late final FirebaseFunctions functions;
final FirebaseFirestore firestore = FirebaseFirestore.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  functions = FirebaseFunctions.instanceFor(region: 'europe-west2');

  // ✅ Initialise Hive
  await Hive.initFlutter();
  Hive.registerAdapter(RecipeCardModelAdapter());
  await Hive.openBox<RecipeCardModel>('recipes');

  runApp(const RecipeVaultApp());
}

/// Launch control based on Firebase Auth state
class InitialScreen extends StatelessWidget {
  const InitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen(); // ✅ No user? Go to login
        }

        return const WelcomeOrHomeScreen();
      },
    );
  }
}

/// Decides between Welcome or Home screen after login
class WelcomeOrHomeScreen extends StatefulWidget {
  const WelcomeOrHomeScreen({super.key});

  @override
  State<WelcomeOrHomeScreen> createState() => _WelcomeOrHomeScreenState();
}

class _WelcomeOrHomeScreenState extends State<WelcomeOrHomeScreen> {
  bool? _hasSeenWelcome;

  @override
  void initState() {
    super.initState();
    _checkSeenWelcome();
  }

  Future<void> _checkSeenWelcome() async {
    if (kAlwaysShowWelcome) {
      setState(() => _hasSeenWelcome = false);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSeenWelcome == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _hasSeenWelcome! ? const HomeScreen() : const WelcomeScreen();
  }
}

/// Router config
final GoRouter _router = GoRouter(
  routes: <GoRoute>[
    GoRoute(path: '/', builder: (context, state) => const InitialScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/results',
      builder: (context, state) => const ResultsScreen(),
    ),
    GoRoute(
      path: '/processing',
      builder: (context, state) {
        final List<File>? imageFiles = state.extra as List<File>?;
        if (imageFiles != null && imageFiles.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ProcessingOverlay.show(context, imageFiles);
          });
        } else {
          debugPrint('⚠️ No image files passed to /processing route.');
        }
        return const SizedBox.shrink();
      },
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ), // ✅ Added
  ],
);

/// App entry
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
