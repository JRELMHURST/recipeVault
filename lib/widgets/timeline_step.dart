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

  static const _dotSize = 12.0;
  static const _dotSizeCurrent = 18.0;
  static const _lineWidth = 2.0;
  static const _lineHeight = 32.0;
  static const _animDuration = Duration(milliseconds: 250);
  static const _curve = Curves.easeInOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color dotColor = isCompleted
        ? theme.colorScheme.primary
        : isCurrent
        ? theme.colorScheme.primary.withOpacity(0.9)
        : theme.disabledColor;

    final Color lineColor = (isCompleted || isCurrent)
        ? theme.colorScheme.primary.withOpacity(0.6)
        : theme.disabledColor.withOpacity(0.4);

    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
      color: (isCompleted || isCurrent)
          ? theme.colorScheme.onSurface
          : theme.disabledColor,
      height: 1.25,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + Line rail
          Column(
            children: [
              AnimatedContainer(
                duration: _animDuration,
                curve: _curve,
                width: isCurrent ? _dotSizeCurrent : _dotSize,
                height: isCurrent ? _dotSizeCurrent : _dotSize,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast) ...[
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: _animDuration,
                  curve: _curve,
                  width: _lineWidth,
                  height: _lineHeight,
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
              // Convey state to screen readers
              hint: isCurrent
                  ? MaterialLocalizations.of(context).currentDateLabel
                  : (isCompleted ? 'Completed' : 'Pending'),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: textStyle ?? const TextStyle(),
                child: Text(label, softWrap: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
