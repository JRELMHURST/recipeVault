// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/core/daily_message_service.dart';

/// A compact launcher button that shows today's tip in a dialog.
/// Keeps the same class name to avoid refactors.
class DailyMessageBubble extends StatefulWidget {
  const DailyMessageBubble({super.key});

  @override
  State<DailyMessageBubble> createState() => _DailyMessageBubbleState();
}

class _DailyMessageBubbleState extends State<DailyMessageBubble> {
  bool _unreadToday = true;

  @override
  void initState() {
    super.initState();
    _restoreState();
  }

  String _todayKey() {
    final now = DateTime.now();
    return 'dailyBubbleDismissed_${now.year}_${now.month}_${now.day}';
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_todayKey()) ?? false;
    if (!mounted) return;
    setState(() => _unreadToday = !dismissed);
  }

  Future<void> _markRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_todayKey(), true);
    if (!mounted) return;
    setState(() => _unreadToday = false);
  }

  Future<void> _openDialog() async {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final message = DailyMessageService.getTodayMessage(context);
    final body = message.isEmpty ? t.dailyMessagePlaceholder : message;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.emoji_objects_rounded,
                    size: 22,
                    color: isDark
                        ? Colors.tealAccent.shade100
                        : Colors.teal.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.dailyTipTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: t.close,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.left,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14.5,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.gotIt),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await _markRead();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Compact, circular launcher with an unread dot.
    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: theme.colorScheme.surface,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: AppLocalizations.of(context).dailyTipTitle,
            onPressed: _openDialog,
            icon: const Icon(Icons.emoji_objects_rounded),
          ),
          if (_unreadToday)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
