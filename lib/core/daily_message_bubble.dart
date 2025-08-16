// daily_message_bubble.dart
// ignore_for_file: file_names, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/core/daily_message_service.dart';
import 'package:recipe_vault/core/daily_tip_banner_controller.dart';

class DailyMessageBubble extends StatefulWidget {
  const DailyMessageBubble({super.key});

  @override
  State<DailyMessageBubble> createState() => _DailyMessageBubbleState();
}

class _DailyMessageBubbleState extends State<DailyMessageBubble>
    with TickerProviderStateMixin {
  final _controller = DailyTipBannerController();
  bool _busy = false;

  Future<void> _showTipBanner() async {
    if (!mounted || _busy) return;
    _busy = true;

    try {
      // Always close before reopening
      await _controller.close();

      // Let the overlay clean up before reinserting
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;

      final t = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      final msg = DailyMessageService.getTodayMessage(context);
      final body = msg.isEmpty ? t.dailyMessagePlaceholder : msg;

      await _controller.show(
        context: context,
        vsync: this,
        autoCloseAfter: const Duration(seconds: 6),
        topMargin: 64,
        maxWidth: 480,
        content: _BannerBody(
          title: t.dailyTipTitle,
          body: body,
          isDark: isDark,
          onClose: _controller.close,
        ),
      );
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).dailyTipTitle,
      onPressed: _showTipBanner,
      icon: const Icon(Icons.emoji_objects_rounded),
    );
  }
}

class _BannerBody extends StatelessWidget {
  final String title;
  final String body;
  final bool isDark;
  final Future<void> Function() onClose;

  const _BannerBody({
    required this.title,
    required this.body,
    required this.isDark,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔆 Round gradient icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.teal.shade300, Colors.teal.shade500]
                    : [Colors.teal.shade600, Colors.teal.shade400],
              ),
            ),
            child: const Icon(Icons.emoji_objects_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),

          // 📝 Text + actions
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onClose,
                      child: Text(
                        AppLocalizations.of(context).close,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context).gotIt,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ❌ Close icon
          IconButton(
            padding: const EdgeInsets.only(left: 4),
            constraints: const BoxConstraints(),
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
