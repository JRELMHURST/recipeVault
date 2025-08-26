// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/billing/subscription/subscription_service.dart';

class TierBadge extends StatelessWidget {
  final bool showAsTitle;
  final Color? overrideColor;

  const TierBadge({super.key, this.showAsTitle = false, this.overrideColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final sub = context.read<SubscriptionService>();

    return ValueListenableBuilder<String>(
      valueListenable: sub.tierNotifier,
      builder: (context, tier, _) {
        final isNone = tier.isEmpty || tier == 'none';
        final isSpecial = sub.hasSpecialAccess;

        // Map tiers to labels + base colours
        final (label, color) = switch (tier) {
          'home_chef' => (loc.planHomeChef, Colors.teal),
          'master_chef' => (loc.planMasterChef, Colors.amber),
          _ => (loc.appTitle, (overrideColor ?? Colors.white)),
        };

        final baseColor = overrideColor ?? color;

        if (showAsTitle) {
          // Title-style badge for app bars/headers
          final titleText = isNone
              ? loc.appTitle
              : '${isSpecial ? '⭐ ' : ''}$label';

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Text(
              titleText,
              key: ValueKey('title_$tier$isSpecial'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                height: 1.2,
                color: baseColor,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        // Chip-style badge for inline usage
        if (isNone) return const SizedBox.shrink();

        final chipText = '${isSpecial ? '⭐ ' : ''}$label';

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Container(
            key: ValueKey('chip_$tier$isSpecial'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: baseColor.withOpacity(0.6)),
            ),
            child: Text(
              chipText,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: baseColor,
              ),
            ),
          ),
        );
      },
    );
  }
}
