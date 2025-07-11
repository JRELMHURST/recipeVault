// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';
import 'package:recipe_vault/login/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/screens/welcome_screen/bouncy_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 800),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    AuthService().logCurrentUser();
  }

  Future<void> _startProcessingFlow() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenWelcome', true);

      final compressedFiles =
          await ImageProcessingService.pickAndCompressImages();

      setState(() => _isLoading = false);

      if (compressedFiles.isEmpty) {
        _showError('No images selected or failed to compress.');
        return;
      }

      if (!mounted) return;

      ProcessingOverlay.show(context, compressedFiles);
    } catch (e) {
      debugPrint('Image processing failed: $e');
      _showError('Something went wrong.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _skipToHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);

    await SubscriptionService().refresh();

    final hasAccess = SubscriptionService().hasAccess;

    if (!mounted) return;

    if (hasAccess) {
      context.pushReplacement('/home');
    } else {
      context.go('/pricing');
    }
  }

  Future<void> _goToPricing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
    if (mounted) context.go('/pricing');
  }

  Future<void> _logOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE6E2FF), Color(0xFFF7F4FB)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _controller,
                    curve: Curves.easeOut,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Image.asset(
                          'assets/icon/round_vaultLogo.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Text(
                        'RecipeVault',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Less faff, more flavour.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          color: theme.colorScheme.primary.withOpacity(0.75),
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Effortlessly turn screenshots into\ndelicious, shareable recipe cards.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 17,
                          height: 1.5,
                          color: theme.colorScheme.onSurface.withOpacity(0.72),
                        ),
                      ),
                      const SizedBox(height: 42),
                      BouncyButton(
                        onPressed: _startProcessingFlow,
                        label: 'Generate Recipe Card',
                        icon: Icons.camera_alt_rounded,
                        color: theme.colorScheme.primary,
                        textColor: Colors.white,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _skipToHome,
                            child: const Text('Skip to Home'),
                          ),
                          TextButton(
                            onPressed: _goToPricing,
                            child: const Text('Back to Pricing'),
                          ),
                          TextButton(
                            onPressed: _logOut,
                            child: const Text('Log Out'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No faff. No ads. Just recipes.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isLoading) const LoadingOverlay(),
      ],
    );
  }
}
