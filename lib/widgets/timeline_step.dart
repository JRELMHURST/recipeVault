// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class TimelineStep extends StatelessWidget {
  final String label;
  final bool isCompleted;
  final bool isCurrent;

  const TimelineStep({
    super.key,
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isCompleted
        ? Colors.green
        : isCurrent
        ? theme.colorScheme.primary
        : Colors.grey[300];

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 16,
          height: 16,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isCurrent
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ],
    );
  }
}
