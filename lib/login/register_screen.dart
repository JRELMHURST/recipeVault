// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/login/auth_service.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';
import 'package:recipe_vault/revcat_paywall/widgets/taster_trial_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _maybeOfferTasterTrial(BuildContext context) async {
    final tier = SubscriptionService().getCurrentTierName();
    if (tier == 'Free') {
      await showDialog(
        context: context,
        builder: (_) => const TasterTrialDialog(),
      );
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      final isTrial =
          GoRouterState.of(context).uri.queryParameters['trial'] == 'true';

      if (isTrial) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ You’re now in your 7-day free trial!'),
          ),
        );
      }

      await _maybeOfferTasterTrial(context);

      final tier = SubscriptionService().getCurrentTierName();
      if (tier == 'Free' || tier == 'Taster') {
        context.go('/pricing');
      } else {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();

      if (!mounted) return;

      final isTrial =
          GoRouterState.of(context).uri.queryParameters['trial'] == 'true';

      if (isTrial) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ You’re now in your 7-day free trial!'),
          ),
        );
      }

      await _maybeOfferTasterTrial(context);

      final tier = SubscriptionService().getCurrentTierName();
      if (tier == 'Free' || tier == 'Taster') {
        context.go('/pricing');
      } else {
        context.go('/home');
      }
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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icon/round_vaultLogo.png', width: 120),
              const SizedBox(height: 24),
              Text(
                'Create an Account',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) => value != null && value.contains('@')
                          ? null
                          : 'Enter a valid email',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) => value != null && value.length >= 6
                          ? null
                          : 'Minimum 6 characters',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: Text(
                  _isLoading ? 'Creating account...' : 'Register with Email',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _registerWithGoogle,
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Register with Google'),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () => GoRouter.of(context).go('/login'),
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
