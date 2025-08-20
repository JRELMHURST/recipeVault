// ignore_for_file: deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:recipe_vault/auth/auth_service.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/features/recipe_vault/vault_recipe_service.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

// ✅ Centralised routes + safe navigation
import 'package:recipe_vault/app/routes.dart';
import 'package:recipe_vault/navigation/nav_utils.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Simple email check (client-side only; Firebase still validates server-side)
  final _emailRegex = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerWithEmail() async {
    FocusScope.of(context).unfocus();
    final loc = AppLocalizations.of(context);

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    // ✅ Basic local validation
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      _showError(loc.invalidEmail);
      return;
    }
    if (password.length < 6) {
      _showError(loc.passwordTooShort);
      return;
    }
    if (password != confirm) {
      _showError(loc.passwordsDoNotMatch);
      return;
    }

    LoadingOverlay.show(context);
    try {
      await AuthService().registerWithEmail(email: email, password: password);
      await VaultRecipeService.loadAndMergeAllRecipes();

      if (!mounted) return;
      // Redirect logic decides if they see vault or paywall
      safeGo(context, AppRoutes.vault);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_mapAuthError(e, loc));
    } catch (e) {
      if (!mounted) return;
      _showError('${loc.registrationFailed}: $e');
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _signUpWithGoogle() async {
    FocusScope.of(context).unfocus();
    final loc = AppLocalizations.of(context);

    LoadingOverlay.show(context);
    try {
      final credential = await AuthService().signInWithGoogle();
      if (credential == null) {
        _showError(loc.googleSignupCancelled);
        return;
      }
      await VaultRecipeService.loadAndMergeAllRecipes();

      if (!mounted) return;
      safeGo(context, AppRoutes.vault);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_mapAuthError(e, loc));
    } catch (e) {
      if (!mounted) return;
      _showError('${loc.googleSignupFailed}: $e');
    } finally {
      LoadingOverlay.hide();
    }
  }

  Future<void> _signUpWithApple() async {
    FocusScope.of(context).unfocus();
    final loc = AppLocalizations.of(context);

    LoadingOverlay.show(context);
    try {
      final credential = await AuthService().signInWithApple();
      if (credential == null) {
        _showError(loc.appleSignupCancelled);
        return;
      }
      await VaultRecipeService.loadAndMergeAllRecipes();

      if (!mounted) return;
      safeGo(context, AppRoutes.vault);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_mapAuthError(e, loc));
    } catch (e) {
      if (!mounted) return;
      _showError('${loc.appleSignupFailed}: $e');
    } finally {
      LoadingOverlay.hide();
    }
  }

  void _goToLogin() => safeGo(context, AppRoutes.login);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ✅ Map FirebaseAuth error codes to friendly messages
  String _mapAuthError(FirebaseAuthException e, AppLocalizations loc) {
    switch (e.code) {
      case 'weak-password':
        return loc.passwordTooShort;
      case 'email-already-in-use':
        return loc.emailInUse;
      case 'invalid-email':
        return loc.invalidEmail;
      case 'operation-not-allowed':
        return loc.registrationDisabled;
      default:
        return loc.unknownError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final wide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFE6E2FF),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              wide ? 48 : 24,
              32,
              wide ? 48 : 24,
              32 + bottomInset,
            ),
            child: ResponsiveWrapper(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AutofillGroup(
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
                                loc.createAccountTitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                loc.trialLine,
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
                                keyboardType: TextInputType.emailAddress,
                                textCapitalization: TextCapitalization.none,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                scrollPadding: const EdgeInsets.only(
                                  bottom: 120,
                                ),
                                decoration: InputDecoration(
                                  labelText: loc.emailLabel,
                                  border: const OutlineInputBorder(),
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
                                scrollPadding: const EdgeInsets.only(
                                  bottom: 120,
                                ),
                                decoration: InputDecoration(
                                  labelText: loc.passwordLabel,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: confirmPasswordController,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                scrollPadding: const EdgeInsets.only(
                                  bottom: 120,
                                ),
                                decoration: InputDecoration(
                                  labelText: loc.confirmPasswordLabel,
                                  border: const OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _registerWithEmail(),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _registerWithEmail,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: Text(
                                    loc.createAccountButton,
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
                                label: Text(loc.continueWithGoogle),
                                onPressed: _signUpWithGoogle,
                              ),
                              const SizedBox(height: 12),
                              if (defaultTargetPlatform == TargetPlatform.iOS)
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.apple,
                                    color: Colors.black,
                                  ),
                                  label: Text(loc.continueWithApple),
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
                                  onPressed: _signUpWithApple,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: _goToLogin,
                          child: Text(loc.alreadyHaveAccountCta),
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
    );
  }
}
