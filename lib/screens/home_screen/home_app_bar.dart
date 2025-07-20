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
          ? const _TierAppBarTitle()
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

class _TierAppBarTitle extends StatelessWidget {
  const _TierAppBarTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subService = Provider.of<SubscriptionService>(context);
    final tier = subService.tierNotifier.value;

    final isFree = tier.isEmpty || tier == 'none' || tier == 'free';
    if (isFree) {
      return Text(
        'RecipeVault',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    final tierLabels = {
      'taster': ('🥄', 'Taster'),
      'home_chef': ('👨‍🍳', 'Home Chef'),
      'master_chef': ('👑', 'Master Chef'),
    };

    final (emoji, label) = tierLabels[tier] ?? ('❓', 'Unknown');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          emoji,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 24,
            height: 1,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            height: 1.2,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
