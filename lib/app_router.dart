// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/processing_overlay.dart';

import '../screens/welcome_screen.dart';
import '../screens/home_screen.dart';
import '../screens/results_screen.dart';
import '../login/login_screen.dart';
import '../login/register_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/acount_settings/account_settings_screen.dart';
import '../settings/appearance_settings_screen.dart';
import '../settings/notifications_settings_screen.dart';
import '../settings/subscription_settings_screen.dart';
import '../settings/about_screen.dart';
import '../revcat_paywall/screens/subscription_success_screen.dart';
import '../revcat_paywall/screens/upgrade_blocked_screen.dart';
import '../revcat_paywall/screens/paywall_screen.dart';
import '../login/dev_tool_screen.dart';
import '../revcat_paywall/services/subscription_manager.dart';

GoRouter createAppRouter(ThemeNotifier themeNotifier) {
  return GoRouter(
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
        path: '/settings/appearance',
        builder: (context, state) => AppearanceSettingsScreen(
          themeNotifier: Provider.of<ThemeNotifier>(context),
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
      GoRoute(
        path: '/dev-tools',
        builder: (context, state) => const DevToolScreen(),
      ),
    ],
  );
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
