// lib/widgets/tier_badge.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class TierBadge extends StatefulWidget {
  final String tier;
  final bool showAsTitle;

  const TierBadge({super.key, required this.tier, this.showAsTitle = false});

  @override
  State<TierBadge> createState() => _TierBadgeState();
}

class _TierBadgeState extends State<TierBadge> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.tier.isEmpty || widget.tier == 'none') {
      return const SizedBox.shrink();
    }

    final Map<String, (String emoji, Color colour)> tierMap = {
      'master_chef': ('👑 Master Chef', Colors.amber),
      'home_chef': ('👨‍🍳 Home Chef', Colors.teal),
      'taster': ('🥄 Taster', Colors.deepPurple),
    };

    final (label, colour) = tierMap[widget.tier] ?? ('❓ Unknown', Colors.grey);

    final titleText = Text(
      label,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: colour,
      ),
    );

    final badge = Container(
      key: ValueKey(widget.tier),
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: widget.showAsTitle ? titleText : badge,
    );
  }
}
