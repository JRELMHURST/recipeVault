// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class TimelineStep extends StatelessWidget {
  final String label;
  final bool isCurrent;
  final bool isCompleted;
  final bool isLast;

  const TimelineStep({
    super.key,
    required this.label,
    required this.isCurrent,
    required this.isCompleted,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dotColor = isCompleted
        ? theme.colorScheme.primary
        : isCurrent
        ? theme.colorScheme.primary.withOpacity(0.9)
        : theme.disabledColor;

    final lineColor = (isCompleted || isCurrent)
        ? theme.colorScheme.primary.withOpacity(0.6)
        : theme.disabledColor.withOpacity(0.4);

    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
      color: isCompleted || isCurrent
          ? theme.colorScheme.onSurface
          : theme.disabledColor,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + Line
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: isCurrent ? 18 : 12,
                height: isCurrent ? 18 : 12,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast) ...[
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: 2,
                  height: 32,
                  color: lineColor,
                ),
              ],
            ],
          ),
          const SizedBox(width: 16),
          // Label
          Expanded(
            child: Semantics(
              label: label,
              selected: isCurrent,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: textStyle ?? const TextStyle(),
                child: Text(label),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
