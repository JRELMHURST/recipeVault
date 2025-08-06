// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:recipe_vault/firebase_auth_service.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/screens/recipe_vault/vault_recipe_service.dart';
import 'dart:io' show Platform;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerWithEmail() async {
    FocusScope.of(context).unfocus();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    if (password != confirm) {
      _showError('Passwords do not match');
      return;
    }

    LoadingOverlay.show(context);
    try {
      await AuthService().registerWithEmail(email, password);
      await VaultRecipeService.loadAndMergeAllRecipes();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showError('Registration failed: $e');
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _signUpWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final credential = await AuthService().signInWithGoogle();
      if (credential == null) {
        _showError('Google sign-up was cancelled.');
        return;
      }

      await VaultRecipeService.loadAndMergeAllRecipes();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showError('Google sign-up failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithApple() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final credential = await AuthService().signInWithApple();
      if (credential == null) {
        _showError('Apple sign-up was cancelled.');
        return;
      }

      await VaultRecipeService.loadAndMergeAllRecipes();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showError('Apple sign-up failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: const Color(0xFFE6E2FF),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width > 600
                        ? 48
                        : 24,
                    vertical: 32,
                  ),
                  child: ResponsiveWrapper(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
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
                                    'Create your\nRecipeVault account',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepPurple,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Enjoy a 7-day free trial – no card required.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  TextField(
                                    controller: emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textCapitalization: TextCapitalization.none,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.email],
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: passwordController,
                                    obscureText: true,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: confirmPasswordController,
                                    obscureText: true,
                                    textInputAction: TextInputAction.done,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirm Password',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _registerWithEmail,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      child: const Text(
                                        'Create Account',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.login),
                                    label: const Text('Continue with Google'),
                                    onPressed: _isLoading
                                        ? null
                                        : _signUpWithGoogle,
                                  ),
                                  const SizedBox(height: 12),
                                  if (Platform.isIOS)
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.apple,
                                        color: Colors.black,
                                      ),
                                      label: const Text('Continue with Apple'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.black,
                                        backgroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Colors.black12,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                          horizontal: 16,
                                        ),
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : _signUpWithApple,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: _goToLogin,
                              child: const Text(
                                'Already have an account? Log in',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
