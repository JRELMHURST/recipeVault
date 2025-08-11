// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/core/daily_message_service.dart';

class DailyMessageBubble extends StatefulWidget {
  const DailyMessageBubble({super.key});

  @override
  State<DailyMessageBubble> createState() => _DailyMessageBubbleState();
}

class _DailyMessageBubbleState extends State<DailyMessageBubble> {
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _checkDismissed();
  }

  Future<void> _checkDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_todayKey()) ?? false;
    if (dismissed) {
      setState(() => _isVisible = false);
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return 'dailyBubbleDismissed_${now.year}_${now.month}_${now.day}';
  }

  Future<void> _dismissBubble() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_todayKey(), true);
    setState(() => _isVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final message = DailyMessageService.getTodayMessage(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final background = isDark
        ? const Color(0xFF2A2E39)
        : const Color(0xFFEAF6F2);
    final border = isDark ? const Color(0xFF3E4453) : const Color(0xFFD3ECE5);
    final iconColour = isDark
        ? Colors.tealAccent.shade100
        : Colors.teal.shade700;

    return Dismissible(
      key: const Key('daily_message_bubble'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _dismissBubble(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.close, color: iconColour.withOpacity(0.4)),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.04)
                  : Colors.teal.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.emoji_objects_rounded, size: 22, color: iconColour),
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
      ),
    );
  }
}
