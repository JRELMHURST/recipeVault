// lib/widgets/loading_overlay.dart
// Unified LoadingOverlay with show()/hide(), animation, and i18n message.

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class LoadingOverlay {
  static bool _isShowing = false;
  static BuildContext? _dialogContext;

  /// Show the loading overlay. If already showing, this is a no-op.
  static Future<void> show(BuildContext context, {String? message}) async {
    if (_isShowing) return;
    _isShowing = true;

    // Use rootNavigator to ensure we’re on top of everything.
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Loading',
      barrierColor: Colors.black.withOpacity(0.40),
      useRootNavigator: true,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) {
        _dialogContext = ctx;
        return _LoadingDialog(message: message);
      },
      transitionBuilder: (ctx, anim, _, child) {
        // Fade + gentle scale
        final fade = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        final scale = Tween<double>(begin: 0.98, end: 1.0).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );

    // When dialog fully closes, reset guards
    _isShowing = false;
    _dialogContext = null;
  }

  /// Hide the overlay if it’s currently showing.
  static void hide() {
    if (!_isShowing) return;
    final ctx = _dialogContext;
    if (ctx != null) {
      // Pop the route hosting the dialog.
      Navigator.of(ctx, rootNavigator: true).pop();
    }
    _isShowing = false;
    _dialogContext = null;
  }
}

class _LoadingDialog extends StatelessWidget {
  final String? message;
  const _LoadingDialog({this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final displayMessage = message ?? localizations.loading;

    // Centered card with spinner + message
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  displayMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
