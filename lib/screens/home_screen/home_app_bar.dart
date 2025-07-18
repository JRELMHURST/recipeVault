import 'package:flutter/material.dart';
import 'package:recipe_vault/screens/home_screen/tier_badge.dart';

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

    final showToggle =
        selectedIndex == 1 && viewModeIcon != null && onToggleViewMode != null;

    return AppBar(
      elevation: 0,
      backgroundColor: theme.appBarTheme.backgroundColor,
      centerTitle: true,
      leading: showToggle
          ? IconButton(
              icon: Icon(
                viewModeIcon,
                color: theme.appBarTheme.iconTheme?.color,
              ),
              onPressed: onToggleViewMode,
            )
          : null,
      title: selectedIndex == 1
          ? const TierBadge(showAsTitle: true)
          : Text(switch (selectedIndex) {
              0 => 'Create',
              1 => 'RecipeVault', // fallback
              2 => 'Settings',
              _ => 'RecipeVault',
            }, style: theme.appBarTheme.titleTextStyle),
      actions: showToggle
          ? [
              // Invisible placeholder to balance the leading icon
              Opacity(
                opacity: 0,
                child: IconButton(icon: Icon(viewModeIcon), onPressed: () {}),
              ),
            ]
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
