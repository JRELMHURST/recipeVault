// lib/widgets/tier_badge.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class TierBadge extends StatelessWidget {
  final String tier;

  const TierBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (tier.isEmpty || tier == 'none') return const SizedBox.shrink();

    final Map<String, (String emoji, Color colour)> tierMap = {
      'master_chef': ('👑 Master Chef', Colors.amber),
      'home_chef': ('👨‍🍳 Home Chef', Colors.teal),
      'taster': ('🥄 Taster', Colors.deepPurple),
    };

    final (label, colour) = tierMap[tier] ?? ('❓ Unknown', Colors.grey);

    return Container(
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
  }
}
