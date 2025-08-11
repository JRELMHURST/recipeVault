// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/firebase_auth_service.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/screens/recipe_vault/vault_recipe_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  late FocusNode _emailFocus;

  @override
  void initState() {
    super.initState();
    _emailFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emailFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    FocusScope.of(context).unfocus();
    LoadingOverlay.show(context);
    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      await AuthService().signInWithEmail(email, password);
      await VaultRecipeService.loadAndMergeAllRecipes();

      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 100));
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      _showError(_friendlyAuthError(e));
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    LoadingOverlay.show(context);
    try {
      final credential = await AuthService().signInWithGoogle();
      if (credential == null) {
        _showError(AppLocalizations.of(context)!.cancel);
        return;
      }
      await VaultRecipeService.loadAndMergeAllRecipes();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 100));
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      _showError(_friendlyAuthError(e));
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _signInWithApple() async {
    FocusScope.of(context).unfocus();
    LoadingOverlay.show(context);
    try {
      final credential = await AuthService().signInWithApple();
      if (credential == null) {
        _showError(AppLocalizations.of(context)!.cancel);
        return;
      }
      await VaultRecipeService.loadAndMergeAllRecipes();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 100));
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      _showError(_friendlyAuthError(e));
    } finally {
      LoadingOverlay.hide();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyAuthError(Object e) {
    final message = e.toString().toLowerCase();
    if (message.contains('invalid-credential')) {
      return AppLocalizations.of(context)!.error;
    }
    if (message.contains('user-not-found')) {
      return AppLocalizations.of(context)!.no;
    }
    if (message.contains('wrong-password')) {
      return AppLocalizations.of(context)!.networkError;
    }
    if (message.contains('too-many-requests')) {
      return AppLocalizations.of(context)!.unknownError;
    }
    if (message.contains('network-request-failed')) {
      return AppLocalizations.of(context)!.networkError;
    }
    return AppLocalizations.of(context)!.unknownError;
  }

  void _goToRegister() {
    Navigator.pushNamed(context, '/register');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFFE6E2FF),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ResponsiveWrapper(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/icon/round_vaultLogo.png',
                            height: 64,
                            width: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            loc.welcomeMessage,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            loc.trialAvailable,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: loc.emailLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: loc.passwordLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _signInWithEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                loc.signInWithEmail,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.login),
                            label: Text(loc.signInWithGoogle),
                            onPressed: _signInWithGoogle,
                          ),
                          const SizedBox(height: 12),
                          if (Theme.of(context).platform == TargetPlatform.iOS)
                            OutlinedButton.icon(
                              icon: const Icon(
                                Icons.apple,
                                color: Colors.black,
                              ),
                              label: Text(loc.signInWithApple),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Colors.black12),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                              ),
                              onPressed: _signInWithApple,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _goToRegister,
                      child: Text(loc.registerCta),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
