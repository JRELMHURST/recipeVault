// lib/widgets/timeline_step.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class TimelineStep extends StatelessWidget {
  final String label;
  final bool isCurrent;
  final bool isCompleted;

  const TimelineStep({
    super.key,
    required this.label,
    required this.isCurrent,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color dotColor = isCompleted
        ? theme.colorScheme.primary
        : isCurrent
        ? theme.colorScheme.primary.withOpacity(0.9)
        : theme.disabledColor;

    final double dotSize = isCurrent ? 18 : 12;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Dot + Line Column
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 2,
                  height: 32,
                  color: isCompleted || isCurrent
                      ? theme.colorScheme.primary.withOpacity(0.6)
                      : theme.disabledColor.withOpacity(0.4),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Label
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: theme.textTheme.bodyLarge!.copyWith(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted || isCurrent
                      ? theme.colorScheme.onSurface
                      : theme.disabledColor,
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
