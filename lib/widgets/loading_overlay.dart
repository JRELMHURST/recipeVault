// lib/widgets/loading_overlay.dart
// Unified LoadingOverlay with show()/hide(), animation, and i18n message.

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
// Use your app's root navigator key, if available
import 'package:recipe_vault/navigation/nav_keys.dart';

class LoadingOverlay {
  static bool _isShowing = false;
  static NavigatorState? _rootNavigator; // <-- hold a stable navigator

  /// Show the loading overlay. If already showing, it's a no-op.
  static Future<void> show(BuildContext context, {String? message}) async {
    if (_isShowing) return;
    _isShowing = true;

    // Prefer the app's root navigator context if we have it.
    final navContext = NavKeys.root.currentContext ?? context;

    unawaited(
      showGeneralDialog(
        context: navContext,
        barrierDismissible: false,
        barrierLabel: AppLocalizations.of(navContext).loading,
        barrierColor: Colors.black.withOpacity(0.40),
        useRootNavigator: true,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, _, __) {
          // Capture the (root) navigator now, so we never look it up later from a disposed ctx.
          _rootNavigator = Navigator.of(ctx, rootNavigator: true);
          return _LoadingDialog(message: message);
        },
        transitionBuilder: (ctx, anim, _, child) {
          final fade = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          final scale = Tween<double>(begin: 0.98, end: 1.0).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
      ).whenComplete(() {
        // If popped externally, reset our guards.
        _isShowing = false;
        _rootNavigator = null;
      }),
    );
  }

  /// Hide the overlay if it’s currently showing.
  /// Safe against route transitions / disposed trees.
  static void hide() {
    // Mark as not showing right away to prevent duplicate pops.
    _isShowing = false;

    final nav = _rootNavigator;
    if (nav == null) {
      // Nothing to pop (already gone or never shown)
      return;
    }

    void attemptPop() {
      try {
        if (nav.mounted && nav.canPop()) {
          nav.pop();
        }
      } catch (_) {
        // If navigator is "locked", try next frame.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            if (nav.mounted && nav.canPop()) {
              nav.pop();
            }
          } catch (_) {
            // Swallow — route already gone or still locked.
          } finally {
            _rootNavigator = null;
          }
        });
        return;
      }
      _rootNavigator = null;
    }

    // Schedule for next frame to avoid popping during a transition.
    SchedulerBinding.instance.addPostFrameCallback((_) => attemptPop());
  }

  /// Convenience helper to run an async task with the overlay shown.
  static Future<T> runWithOverlay<T>(
    BuildContext context,
    Future<T> Function() task, {
    String? message,
  }) async {
    await show(context, message: message);
    try {
      return await task();
    } finally {
      hide();
    }
  }
}

class _LoadingDialog extends StatelessWidget {
  final String? message;
  const _LoadingDialog({this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final displayMessage = message ?? t.loading;

    final currentScale = MediaQuery.of(context).textScaler;
    final clampedScale = TextScaler.linear(
      currentScale.scale(1.0).clamp(0.9, 1.4),
    );

    final clamped = MediaQuery.of(context).copyWith(textScaler: clampedScale);

    return MediaQuery(
      data: clamped,
      child: Center(
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
              child: Semantics(
                liveRegion: true,
                label: displayMessage,
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
        ),
      ),
    );
  }
}
