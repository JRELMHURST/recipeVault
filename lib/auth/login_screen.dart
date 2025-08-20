// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:recipe_vault/auth/auth_service.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/features/recipe_vault/vault_recipe_service.dart';

import 'package:recipe_vault/app/routes.dart';
import 'package:recipe_vault/navigation/nav_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  late final FocusNode _emailFocus;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _emailFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _emailFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    final loc = AppLocalizations.of(context);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError(
        loc.unknownError,
      ); // or add a dedicated “Please fill both fields”
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    LoadingOverlay.show(context);
    try {
      await AuthService().signInWithEmail(email: email, password: password);
      await VaultRecipeService.loadAndMergeAllRecipes();

      if (!mounted) return;
      // Optional: let global redirects decide destination.
      // If you prefer an explicit nudge, keep this:
      safeGo(context, AppRoutes.vault);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_friendlyAuthError(e));
    } catch (e) {
      if (!mounted) return;
      _showError(AppLocalizations.of(context).unknownError);
    } finally {
      LoadingOverlay.hide();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    LoadingOverlay.show(context);
    try {
      final credential = await AuthService().signInWithGoogle();
      if (credential == null) {
        _showError(AppLocalizations.of(context).cancel);
        return;
      }
      await VaultRecipeService.loadAndMergeAllRecipes();
      if (!mounted) return;
      safeGo(context, AppRoutes.vault);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_friendlyAuthError(e));
    } catch (_) {
      if (!mounted) return;
      _showError(AppLocalizations.of(context).unknownError);
    } finally {
      LoadingOverlay.hide();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    LoadingOverlay.show(context);
    try {
      final credential = await AuthService().signInWithApple();
      if (credential == null) {
        _showError(AppLocalizations.of(context).cancel);
        return;
      }
      await VaultRecipeService.loadAndMergeAllRecipes();
      if (!mounted) return;
      safeGo(context, AppRoutes.vault);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_friendlyAuthError(e));
    } catch (_) {
      if (!mounted) return;
      _showError(AppLocalizations.of(context).unknownError);
    } finally {
      LoadingOverlay.hide();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    final loc = AppLocalizations.of(context);
    switch (e.code) {
      case 'invalid-credential':
      case 'invalid-email':
      case 'user-not-found':
      case 'wrong-password':
        return loc.error; // map to your localized “Invalid email or password”
      case 'user-disabled':
        return loc.no; // replace with a proper “Account disabled” string
      case 'too-many-requests':
        return loc.unknownError; // replace with “Too many attempts” in l10n
      case 'network-request-failed':
        return loc.networkError;
      default:
        return loc.unknownError;
    }
  }

  void _goToRegister() => safeGo(context, AppRoutes.register);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFFE6E2FF),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(24, 32, 24, 32 + bottomInset),
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
                      child: AutofillGroup(
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
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              scrollPadding: const EdgeInsets.only(bottom: 120),
                              decoration: InputDecoration(
                                labelText: loc.emailLabel,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: passwordController,
                              enabled: !_busy,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              scrollPadding: const EdgeInsets.only(bottom: 120),
                              onSubmitted: (_) => _signInWithEmail(),
                              decoration: InputDecoration(
                                labelText: loc.passwordLabel,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _busy ? null : _signInWithEmail,
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
                              onPressed: _busy ? null : _signInWithGoogle,
                            ),
                            const SizedBox(height: 12),
                            if (defaultTargetPlatform == TargetPlatform.iOS)
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
                                onPressed: _busy ? null : _signInWithApple,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _busy ? null : _goToRegister,
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
