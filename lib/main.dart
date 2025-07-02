import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recipe_vault/firebase_auth.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';

import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/results_screen.dart';
import 'core/theme.dart';
import 'core/accessibility.dart';

/// Force welcome screen for dev/test
const bool kAlwaysShowWelcome = true;

/// Globally accessible Firebase Functions instance
late final FirebaseFunctions functions;
final FirebaseFirestore firestore = FirebaseFirestore.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAuthService.signInAnonymously();

  functions = FirebaseFunctions.instanceFor(region: 'europe-west2');

  runApp(const RecipeVaultApp());
}

/// Launch control for deciding between Welcome or Home screen
class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});
  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
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
      return const Center(child: CircularProgressIndicator());
    }
    return _hasSeenWelcome! ? const HomeScreen() : const WelcomeScreen();
  }
}

/// Router for navigation
final GoRouter _router = GoRouter(
  routes: <GoRoute>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const InitialScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
    GoRoute(
      path: '/results',
      builder: (BuildContext context, GoRouterState state) =>
          const ResultsScreen(),
    ),
    GoRoute(
      path: '/processing',
      builder: (BuildContext context, GoRouterState state) {
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
  ],
);

/// The main app widget
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
