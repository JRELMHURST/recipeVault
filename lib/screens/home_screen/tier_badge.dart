// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class TierBadge extends StatelessWidget {
  final bool showAsTitle;
  final Color? overrideColor;

  const TierBadge({super.key, this.showAsTitle = false, this.overrideColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );

    return ValueListenableBuilder<String>(
      valueListenable: subscriptionService.tierNotifier,
      builder: (context, tier, _) {
        // Fallback for unrecognised tiers
        final isFreeTier = tier.isEmpty || tier == 'none' || tier == 'free';
        final isSpecial = subscriptionService.hasSpecialAccess;

        if (isFreeTier) {
          return showAsTitle
              ? Text(
                  'RecipeVault',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: overrideColor ?? Colors.white,
                  ),
                  textAlign: TextAlign.center,
                )
              : const SizedBox.shrink();
        }

        // Known tiers with labels and default colours
        final tierStyles = {
          'taster': ('Taster', Colors.deepPurple),
          'home_chef': ('Home Chef', Colors.teal),
          'master_chef': ('Master Chef', Colors.amber),
        };

        final style = tierStyles[tier];
        String label = style?.$1 ?? '❓ Unknown';
        final baseColour = overrideColor ?? style?.$2 ?? Colors.grey;

        // ✨ Add star for special Home Chef users
        if (tier == 'home_chef' && isSpecial) {
          label = '⭐ $label';
        }

        if (showAsTitle) {
          final parts = label.split(' ');
          final emoji = parts.first;
          final text = parts.sublist(1).join(' ');

          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 24,
                    height: 1,
                    color: baseColour,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    height: 1.2,
                    color: baseColour,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          key: ValueKey(tier),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: baseColour.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: baseColour.withOpacity(0.6)),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: baseColour,
            ),
          ),
        );
      },
    );
  }
}
