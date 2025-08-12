// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
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
    _restoreDismissState();
  }

  Future<void> _restoreDismissState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_todayKey()) ?? false;
    if (!mounted) return;
    if (dismissed) setState(() => _isVisible = false);
  }

  String _todayKey() {
    final now = DateTime.now();
    return 'dailyBubbleDismissed_${now.year}_${now.month}_${now.day}';
  }

  Future<void> _dismissBubble() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_todayKey(), true);
    if (!mounted) return;
    setState(() => _isVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final rawMessage = DailyMessageService.getTodayMessage(context);
    final message = (rawMessage.isEmpty)
        ? t.dailyMessagePlaceholder
        : rawMessage;

    final background = isDark
        ? const Color(0xFF2A2E39)
        : const Color(0xFFEAF6F2);
    final border = isDark ? const Color(0xFF3E4453) : const Color(0xFFD3ECE5);
    final iconColour = isDark
        ? Colors.tealAccent.shade100
        : Colors.teal.shade700;

    return Dismissible(
      key: const ValueKey('daily_message_bubble'),
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
          children: [
            Icon(Icons.emoji_objects_rounded, size: 22, color: iconColour),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.dailyTipTitle, // Localised tip title
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message, // Localised or fallback daily message
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: t.dismiss, // Localised dismiss tooltip
              icon: const Icon(Icons.close_rounded, size: 18),
              color: iconColour,
              onPressed: _dismissBubble,
            ),
          ],
        ),
      ),
    );
  }
}
