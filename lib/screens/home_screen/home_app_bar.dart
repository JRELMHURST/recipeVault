// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedIndex;
  final IconData? viewModeIcon;
  final VoidCallback? onToggleViewMode;

  const HomeAppBar({
    super.key,
    required this.selectedIndex,
    this.viewModeIcon,
    this.onToggleViewMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tier = context.watch<SubscriptionService>().tier;

    final showToggle =
        selectedIndex == 1 && viewModeIcon != null && onToggleViewMode != null;

    final isFreeTier = tier.isEmpty || tier == 'none' || tier == 'free';

    return AppBar(
      elevation: 0,
      backgroundColor: theme.appBarTheme.backgroundColor,
      automaticallyImplyLeading: false,
      title: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            _getAppBarTitle(selectedIndex, tier),
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: 1.1,
              fontFamily: 'Roboto',
              shadows: const [
                Shadow(
                  blurRadius: 2,
                  offset: Offset(0, 1),
                  color: Colors.black26,
                ),
              ],
            ),
          ),
        ],
      ),
      leading: showToggle
          ? Tooltip(
              message: 'Toggle view mode',
              waitDuration: const Duration(milliseconds: 300),
              child: IconButton(
                icon: Icon(
                  viewModeIcon,
                  color: theme.appBarTheme.iconTheme?.color,
                ),
                onPressed: onToggleViewMode,
              ),
            )
          : null,
      actions: [
        if ((selectedIndex == 1 || selectedIndex == 2) && isFreeTier)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/paywall'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getAppBarTitle(int index, String tier) {
    if (index != 1) {
      return switch (index) {
        0 => 'Create',
        2 => 'Settings',
        _ => 'RecipeVault',
      };
    }

    return switch (tier) {
      'taster' => '🥄 Taster',
      'home_chef' => '👨‍🍳 Home Chef',
      'master_chef' => '👑 Master Chef',
      _ => 'RecipeVault',
    };
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
