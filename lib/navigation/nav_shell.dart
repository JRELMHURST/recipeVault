// lib/navigation/nav_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/features/home/home_app_bar.dart';
import 'package:recipe_vault/features/recipe_vault/vault_view_mode_notifier.dart';
import 'package:recipe_vault/navigation/routes.dart';
import 'package:recipe_vault/navigation/nav_utils.dart';

import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/billing/subscription_service.dart';
import 'package:recipe_vault/data/services/image_processing_service.dart';
import 'package:recipe_vault/features/processing/processing_overlay.dart';

class NavShell extends StatelessWidget {
  const NavShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    // Which tab should be highlighted?
    final isSettings =
        location == AppRoutes.settings ||
        location.startsWith('${AppRoutes.settings}/');
    final selectedIndex = isSettings ? 2 : 1; // 0 (Create) is action-only

    // Only show the view toggle on Vault tab
    IconData? viewIcon;
    VoidCallback? onToggle;
    if (selectedIndex == 1) {
      final vm = context.watch<VaultViewModeNotifier>();
      viewIcon = vm.icon;
      onToggle = vm.toggle;
    }

    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    final inactive = theme.colorScheme.onSurfaceVariant;

    Widget vaultIcon(bool selected) => Image.asset(
      'assets/icon/lock_icon.png',
      height: selected ? 56 : 48,
      // Remove the color line if you want the original PNG colors.
      color: selected ? active : inactive,
    );

    return Scaffold(
      appBar: HomeAppBar(
        selectedIndex: selectedIndex,
        viewModeIcon: viewIcon,
        onToggleViewMode: onToggle,
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) async {
          switch (i) {
            case 0:
              await _handleCreateAction(context);
              break;
            case 1:
              if (location != AppRoutes.vault) {
                safeGo(context, AppRoutes.vault);
              }
              break;
            case 2:
              if (!isSettings) {
                safeGo(context, AppRoutes.settings);
              }
              break;
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.add_a_photo_outlined),
            label: 'Create',
          ),
          NavigationDestination(
            icon: vaultIcon(false),
            selectedIcon: vaultIcon(true),
            label: 'Vault',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────────── Create action (inline) ─────────────────────────── */

Future<void> _handleCreateAction(BuildContext context) async {
  final loc = AppLocalizations.of(context);
  final subs = context.read<SubscriptionService>();

  // Gate: require paid to upload images
  if (!subs.allowImageUpload) {
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
                    // Route after dialog fully closes
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        safeGo(context, AppRoutes.paywall);
                      }
                    });
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

  // Paid: pick images → processing overlay → ensure we're on Vault
  final files = await ImageProcessingService.pickAndCompressImages();
  if (!context.mounted) return;

  if (files.isNotEmpty) {
    ProcessingOverlay.show(context, files);
    final current = GoRouterState.of(context).matchedLocation;
    if (current != AppRoutes.vault) {
      safeGo(context, AppRoutes.vault);
    }
  }
  // If user canceled, do nothing.
}
