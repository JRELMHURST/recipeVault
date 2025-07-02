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
        ? theme.colorScheme.primary.withAlpha((0.9 * 255).toInt())
        : theme.disabledColor;

    final double dotSize = isCurrent ? 18 : 12;

    final Color lineColor = isCompleted || isCurrent
        ? theme.colorScheme.primary.withAlpha((0.6 * 255).toInt())
        : theme.disabledColor.withAlpha((0.4 * 255).toInt());

    final TextStyle textStyle = theme.textTheme.bodyLarge!.copyWith(
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
          // Timeline Dot + Line
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
              Container(width: 2, height: 32, color: lineColor),
            ],
          ),
          const SizedBox(width: 16),
          // Step Label
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: textStyle,
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}
