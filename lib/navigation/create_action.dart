// lib/navigation/create_action.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';
import 'package:recipe_vault/navigation/routes.dart';

Future<void> handleCreateAction(BuildContext context) async {
  final loc = AppLocalizations.of(context);
  final sub = context.read<SubscriptionService>();

  // If not allowed, show upgrade prompt
  if (!sub.allowImageUpload) {
    HapticFeedback.mediumImpact();

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 48),
              const SizedBox(height: 16),
              Text(
                loc.upgradeToUnlockTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(loc.createFromImagesPaid, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(loc.upgradeToUnlockBody, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop(); // close dialog
                    context.push(AppRoutes.paywall); // then navigate
                  },
                  child: Text(loc.seePlanOptions),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(loc.cancel),
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }

  // Paid: proceed to pick & process images.
  final files = await ImageProcessingService.pickAndCompressImages();
  if (files.isNotEmpty && context.mounted) {
    ProcessingOverlay.show(context, files);
  }

  // After create action, keep user on Vault
  if (context.mounted) context.go(AppRoutes.vault);
}
