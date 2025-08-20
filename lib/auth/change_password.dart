// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/app/routes.dart';
import 'package:recipe_vault/navigation/nav_utils.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _friendlyError(FirebaseAuthException e, AppLocalizations l10n) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return l10n.enterCurrentPassword;
      case 'user-mismatch':
      case 'user-not-found':
        return l10n.no;
      case 'weak-password':
        return l10n.passwordMinLength;
      case 'requires-recent-login':
        return l10n.error; // or a dedicated string
      case 'network-request-failed':
        return l10n.networkError;
      default:
        return l10n.unknownError;
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context);

    if (user == null) {
      // Not signed in anymore; bounce to login via safe helper.
      safeGo(context, AppRoutes.login);
      return;
    }

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPasswordController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passwordUpdated)));
      // Use safe pop so we don't mutate router state mid-build.
      safePop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e, l10n));
    } catch (_) {
      setState(() => _errorMessage = l10n.unknownError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context);

    // If somehow reached while signed out, guard here too.
    if (user == null) {
      // Immediate safe redirect keeps UI consistent.
      safeGo(context, AppRoutes.login);
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePasswordTitle), centerTitle: true),
      body: ResponsiveWrapper(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // ===== Header with pill =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.85),
                      theme.colorScheme.primary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 48, color: Colors.white),
                    if (user.email != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        user.email!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ===== Form card =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        TextFormField(
                          controller: _currentPasswordController,
                          decoration: InputDecoration(
                            labelText: l10n.currentPasswordLabel,
                          ),
                          obscureText: true,
                          enabled: !_isLoading,
                          autofillHints: const [AutofillHints.password],
                          validator: (value) => (value == null || value.isEmpty)
                              ? l10n.enterCurrentPassword
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPasswordController,
                          decoration: InputDecoration(
                            labelText: l10n.newPasswordLabel,
                          ),
                          obscureText: true,
                          enabled: !_isLoading,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (value) =>
                              (value != null && value.length >= 6)
                              ? null
                              : l10n.passwordMinLength,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: l10n.confirmPasswordLabel,
                          ),
                          obscureText: true,
                          enabled: !_isLoading,
                          validator: (value) =>
                              value == _newPasswordController.text
                              ? null
                              : l10n.passwordsDoNotMatch,
                          onFieldSubmitted: (_) => _changePassword(),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _changePassword,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(l10n.updatePasswordButton),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
