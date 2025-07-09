// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/login/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      final isTrial =
          GoRouterState.of(context).uri.queryParameters['trial'] == 'true';
      if (isTrial) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ You’re now in your 7-day free trial!'),
          ),
        );
      }
      GoRouter.of(context).go(isTrial ? '/' : '/home');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithGoogle();

      if (!mounted || result == null) return;

      final isTrial =
          GoRouterState.of(context).uri.queryParameters['trial'] == 'true';
      if (isTrial) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ You’re now in your 7-day free trial!'),
          ),
        );
      }
      GoRouter.of(context).go(isTrial ? '/' : '/home');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/icon/round_vaultLogo.png', width: 100),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to RecipeVault',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value != null && value.contains('@')
                              ? null
                              : 'Enter a valid email',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value != null && value.length >= 6
                              ? null
                              : 'Minimum 6 characters',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _isLoading ? 'Signing in...' : 'Sign in with Email',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Sign in with Google'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(color: theme.colorScheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => GoRouter.of(context).push('/register'),
                    child: const Text("Don't have an account? Register"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
