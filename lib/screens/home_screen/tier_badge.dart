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
        debugPrint('🧪 TierBadge: current tier is "$tier"');

        // Treat 'none', empty or 'free' as Free tier
        final isFree = tier.isEmpty || tier == 'none' || tier == 'free';

        if (isFree) {
          debugPrint(
            '🕒 TierBadge fallback: showing default RecipeVault title',
          );
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

        // Define label and colour for known tiers
        final tierMap = {
          'taster': ('🥄 Taster', Colors.deepPurple),
          'home_chef': ('👨‍🍳 Home Chef', Colors.teal),
          'master_chef': ('👑 Master Chef', Colors.amber),
        };

        final labelColourPair = tierMap[tier];
        final label = labelColourPair?.$1 ?? '❓ Unknown';
        final defaultColour = labelColourPair?.$2 ?? Colors.grey;
        final colour = overrideColor ?? defaultColour;

        debugPrint('✅ TierBadge rendering: "$label"');

        if (showAsTitle) {
          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.split(' ').first, // Emoji
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 24,
                    height: 1,
                    color: colour,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label.split(' ').sublist(1).join(' '), // Label
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    height: 1.2,
                    color: colour,
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
            color: colour.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colour.withOpacity(0.6)),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colour,
            ),
          ),
        );
      },
    );
  }
}
