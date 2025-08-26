// lib/core/home_app_bar.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/core/daily_message_bubble.dart';
import 'package:recipe_vault/billing/subscription/subscription_service.dart';
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
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final subs = context.watch<SubscriptionService>();

    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final titleText = _getAppBarTitle(loc, selectedIndex, subs.tier);

    return AppBar(
      toolbarHeight: 88,
      elevation: 0,
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      automaticallyImplyLeading: false,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary.withOpacity(.96), cs.primary.withOpacity(.80)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
      ),

      // Leading: vault view toggle or settings refresh
      leading: switch (selectedIndex) {
        1 when viewModeIcon != null && onToggleViewMode != null => Tooltip(
          message: loc.appBarToggleViewMode,
          waitDuration: const Duration(milliseconds: 300),
          child: IconButton(
            icon: Icon(viewModeIcon, color: Colors.white),
            onPressed: onToggleViewMode,
          ),
        ),
        2 => Tooltip(
          message: loc.appBarRefreshSubscription,
          waitDuration: const Duration(milliseconds: 300),
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              final subs = context.read<SubscriptionService>();
              await subs.refresh(); // pulls latest from RevenueCat + Firestore
              // Optionally push reconcile if you want immediate backend alignment
              await subs.refreshAndNotify(); // keeps UI in sync

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.subscriptionRefreshed),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ),
        _ => const SizedBox.shrink(),
      },

      title: _GradientTitle(text: titleText),

      // Daily tips bubble (ramen icon)
      actions: [
        if (selectedIndex == 1)
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: DailyMessageBubble(
              iconData: Icons.ramen_dining_rounded,
              tooltip: 'Daily cooking tip',
            ),
          ),
      ],
    );
  }

  String _getAppBarTitle(AppLocalizations loc, int index, String tier) {
    if (index != 1) {
      return switch (index) {
        0 => loc.scanRecipe,
        2 => loc.settings,
        _ => loc.appTitle,
      };
    }
    return switch (tier) {
      'home_chef' => loc.planHomeChef,
      'master_chef' => loc.planMasterChef,
      _ => loc.appTitle,
    };
  }
}

/// Gradient-styled title text only (no emoji badge)
class _GradientTitle extends StatelessWidget {
  const _GradientTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shader = LinearGradient(
          colors: [Colors.white, Colors.white.withOpacity(.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, constraints.maxWidth, 40));

        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: .6,
            foreground: Paint()..shader = shader,
            shadows: const [
              Shadow(
                blurRadius: 2,
                offset: Offset(0, 1),
                color: Colors.black26,
              ),
            ],
          ),
        );
      },
    );
  }
}
