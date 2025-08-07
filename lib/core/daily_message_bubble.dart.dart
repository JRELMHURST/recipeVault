// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/core/daily_message_service.dart';

class DailyMessageBubble extends StatelessWidget {
  const DailyMessageBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final message = DailyMessageService.getTodayMessage();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final background = isDark
        ? Colors.deepPurple.shade50.withOpacity(0.05)
        : const Color(0xFFFFFAEC); // Soft yellow
    final border = isDark
        ? Colors.deepPurple.shade100.withOpacity(0.15)
        : const Color(0xFFFEECCF); // Pale amber
    final iconColour = isDark ? Colors.amber.shade200 : Colors.orange.shade600;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.06)
                : Colors.orange.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.emoji_objects_rounded, size: 20, color: iconColour),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
