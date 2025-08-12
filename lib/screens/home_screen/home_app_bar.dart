// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

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
    final loc = AppLocalizations.of(context);
    final tier = context.watch<SubscriptionService>().tier;

    final isFreeTier = tier.isEmpty || tier == 'none' || tier == 'free';

    return AppBar(
      elevation: 0,
      backgroundColor: theme.appBarTheme.backgroundColor,
      automaticallyImplyLeading: false,
      title: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            _getAppBarTitle(loc, selectedIndex, tier),
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

      // 🔁 Show either toggle or refresh on the leading side
      leading: switch (selectedIndex) {
        1 when viewModeIcon != null && onToggleViewMode != null => Tooltip(
          message: loc.appBarToggleViewMode, // NEW KEY
          waitDuration: const Duration(milliseconds: 300),
          child: IconButton(
            icon: Icon(viewModeIcon, color: theme.appBarTheme.iconTheme?.color),
            onPressed: onToggleViewMode,
          ),
        ),
        2 => Tooltip(
          message: loc.appBarRefreshSubscription, // NEW KEY
          waitDuration: const Duration(milliseconds: 300),
          child: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final subService = context.read<SubscriptionService>();
              await subService.syncRevenueCatEntitlement();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.subscriptionRefreshed), // NEW KEY
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ),
        _ => null,
      },

      // Upgrade button on right if applicable
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
              child: Text(
                loc.upgradeNow,
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getAppBarTitle(AppLocalizations loc, int index, String tier) {
    if (index != 1) {
      return switch (index) {
        // Using existing keys to avoid new strings:
        0 => loc.scanRecipe,
        2 => loc.settings,
        _ => loc.appTitle,
      };
    }

    return switch (tier) {
      'home_chef' => '👨‍🍳 ${loc.planHomeChef}',
      'master_chef' => '👑 ${loc.planMasterChef}',
      _ => loc.appTitle,
    };
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
