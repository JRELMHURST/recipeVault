// lib/core/daily_message_bubble.dart
// ignore_for_file: file_names, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/core/daily_message_service.dart';
import 'package:recipe_vault/core/daily_tip_banner_controller.dart';

class DailyMessageBubble extends StatefulWidget {
  final IconData iconData;
  final String tooltip;

  const DailyMessageBubble({
    super.key,
    this.iconData = Icons.lightbulb, // default
    this.tooltip = 'Daily tip', // default
  });

  @override
  State<DailyMessageBubble> createState() => _DailyMessageBubbleState();
}

class _DailyMessageBubbleState extends State<DailyMessageBubble>
    with TickerProviderStateMixin {
  final _controller = DailyTipBannerController();
  late final AnimationController _pulseCtrl;

  bool _busy = false;
  bool _isUnread = false;

  GoRouter? _router;
  VoidCallback? _routerListener;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _loadReadState();
  }

  Future<void> _loadReadState() async {
    try {
      final read = await DailyMessageService.isTodayRead();
      if (mounted) setState(() => _isUnread = !read);
    } catch (_) {
      if (mounted) setState(() => _isUnread = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = GoRouter.of(context);
    if (_router != r) {
      _detachRouterListener();
      _router = r;
      _routerListener = () {
        _controller.close(immediate: true);
      };
      _router!.routerDelegate.addListener(_routerListener!);
    }
  }

  void _detachRouterListener() {
    if (_router != null && _routerListener != null) {
      _router!.routerDelegate.removeListener(_routerListener!);
    }
    _router = null;
    _routerListener = null;
  }

  Future<void> _showTipBanner() async {
    if (!mounted || _busy) return;
    _busy = true;

    try {
      await _controller.close(immediate: true);
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
        autoCloseAfter: const Duration(seconds: 7),
        topMargin: 64,
        maxWidth: 520,
        enableScrim: false, // ← absolutely no background overlay
        content: _BannerBody(
          title: t.dailyTipTitle,
          body: body,
          isDark: isDark,
          iconData: widget.iconData,
          onClose: () => _controller.close(),
        ),
      );

      try {
        await DailyMessageService.markTodayRead();
      } catch (_) {}
      if (mounted) setState(() => _isUnread = false);
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _detachRouterListener();
    _controller.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseIcon = Icon(widget.iconData, color: Colors.white);
    final unreadDot = Positioned(
      right: 6,
      top: 6,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 240),
        scale: _isUnread ? 1 : 0,
        child: _UnreadBadge(pulse: _pulseCtrl),
      ),
    );

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: _showTipBanner,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InkResponse(
                onTap: _showTipBanner,
                customBorder: const CircleBorder(),
                highlightShape: BoxShape.circle,
                child: const SizedBox.expand(),
              ),
              baseIcon,
              unreadDot,
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────── Helper widgets (kept local to avoid missing-symbol errors) ───────────── */

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.pulse});
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: .2, end: .55).animate(pulse),
          child: ScaleTransition(
            scale: Tween<double>(
              begin: .9,
              end: 1.25,
            ).animate(CurvedAnimation(parent: pulse, curve: Curves.easeInOut)),
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(blurRadius: 10, color: Colors.amberAccent),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.amber.shade700,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      ],
    );
  }
}

class _Sparkle extends StatefulWidget {
  const _Sparkle(this.base);
  final Color base;

  @override
  State<_Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<_Sparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: .45, end: 1).animate(_ctrl),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: 18,
        color: widget.base.withOpacity(.95),
      ),
    );
  }
}

/// Rounded card with subtle gradient border (no blur; no dart:ui import needed)
/// Rounded card with gradient border + subtle shadow
class _BannerBody extends StatelessWidget {
  final String title;
  final String body;
  final bool isDark;
  final IconData iconData;
  final VoidCallback onClose;

  const _BannerBody({
    required this.title,
    required this.body,
    required this.isDark,
    required this.iconData,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(.35), cs.secondary.withOpacity(.35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5), // thickness of border
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon chip
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isDark
                      ? [cs.tertiary, cs.primary]
                      : [cs.primary, cs.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(iconData, color: Colors.white),
            ),
            const SizedBox(width: 14),

            // Text + CTA
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Sparkle(cs.primary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      color: cs.onSurface.withOpacity(.92),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onClose,
                        style: TextButton.styleFrom(
                          foregroundColor: cs.primary,
                        ),
                        child: Text(
                          AppLocalizations.of(context).close,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: onClose,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
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

            // Close
            IconButton(
              padding: const EdgeInsets.only(left: 4),
              constraints: const BoxConstraints(),
              onPressed: onClose,
              icon: Icon(
                Icons.close_rounded,
                color: cs.onSurface.withOpacity(0.70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
