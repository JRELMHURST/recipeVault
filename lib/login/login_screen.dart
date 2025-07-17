// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/firebase_auth_service.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/services/user_session_service.dart'; // ✅ Re-added

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signInWithEmail() async {
    setState(() => _isLoading = true);
    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      await AuthService().signInWithEmail(email, password);

      // ✅ Ensure subscription tier, entitlement, and Firestore sync
      await UserSessionService.init();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyAuthError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final credential = await AuthService().signInWithGoogle();
      if (credential == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in was cancelled.')),
        );
        return;
      }

      // ✅ Ensure subscription tier, entitlement, and Firestore sync
      await UserSessionService.init();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyAuthError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyAuthError(Object e) {
    final message = e.toString().toLowerCase();

    if (message.contains('invalid-credential')) {
      return 'The email or password is incorrect. Please try again.';
    } else if (message.contains('user-not-found')) {
      return 'No account found with this email address.';
    } else if (message.contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    } else if (message.contains('too-many-requests')) {
      return 'Too many attempts. Please wait and try again later.';
    } else if (message.contains('network-request-failed')) {
      return 'Network error. Please check your connection.';
    }

    return 'Login failed. Please check your details and try again.';
  }

  void _goToRegister() {
    Navigator.pushNamed(context, '/register');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Scaffold(
            backgroundColor: const Color(0xFFE6E2FF),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
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
                                'Welcome to\nRecipeVault',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Free 7-day trial. No card needed. Full access.',
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
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: passwordController,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  border: OutlineInputBorder(),
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
                                  child: const Text(
                                    'Sign in with Email',
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
                                label: const Text('Sign in with Google'),
                                onPressed: _signInWithGoogle,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: _goToRegister,
                          child: const Text("Don't have an account? Register"),
                        ),
                      ],
                    ),
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
