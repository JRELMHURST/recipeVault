// lib/navigation/nav_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/features/home/home_app_bar.dart';
import 'package:recipe_vault/features/recipe_vault/vault_view_mode_notifier.dart';
import 'package:recipe_vault/navigation/routes.dart';
import 'package:recipe_vault/navigation/create_action.dart';

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
              await handleCreateAction(context);
              break;
            case 1:
              context.go(AppRoutes.vault);
              break;
            case 2:
              context.go(AppRoutes.settings);
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_a_photo_outlined),
            label: 'Create',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_open_outlined),
            label: 'Vault',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
