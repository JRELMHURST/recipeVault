// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class DismissibleBubble extends StatefulWidget {
  final String message;

  /// Absolute position (global) used when no [anchorKey] is provided.
  final Offset? position;

  /// If provided, the bubble will be positioned just below this widget.
  final GlobalKey? anchorKey;

  final VoidCallback onDismiss;
  final bool showButton;

  const DismissibleBubble({
    super.key,
    required this.message,
    this.position,
    this.anchorKey,
    required this.onDismiss,
    this.showButton = true,
  });

  @override
  State<DismissibleBubble> createState() => _DismissibleBubbleState();
}

class _DismissibleBubbleState extends State<DismissibleBubble>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // Bubble’s top-left in the parent Stack’s local coordinate space.
  Offset _offset = const Offset(16, 80);

  // Track our own size for clamping.
  final GlobalKey _bubbleKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curved);

    // Defer initial measure until after first layout.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _recalculatePosition();
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant DismissibleBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchorKey != widget.anchorKey ||
        oldWidget.position != widget.position) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _recalculatePosition(),
      );
    }
  }

  @override
  void didChangeMetrics() {
    // Orientation/keyboard/safe-area changes → reposition
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _recalculatePosition(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _recalculatePosition() async {
    if (!mounted) return;

    final stackRender = context.findRenderObject();
    if (stackRender is! RenderBox) return;

    // 1) Determine a base *global* position
    Offset baseGlobal = widget.position ?? const Offset(16, 80);
    double belowGap = 8.0;

    final anchorCtx = widget.anchorKey?.currentContext;
    final anchorRender = anchorCtx?.findRenderObject();
    if (anchorRender is RenderBox) {
      final topLeft = anchorRender.localToGlobal(Offset.zero);
      baseGlobal = topLeft;
      belowGap += anchorRender.size.height; // place just below anchor
    }

    // 2) Convert to this Stack’s local space + gap
    final baseLocal =
        stackRender.globalToLocal(baseGlobal) + Offset(0, belowGap);

    // 3) Measure our own size (fallback default)
    final bubbleRender = _bubbleKey.currentContext?.findRenderObject();
    final bubbleSize = (bubbleRender is RenderBox)
        ? bubbleRender.size
        : const Size(240, 80);
    final stackSize = stackRender.size;

    // 4) Clamp inside the visible area of this Stack
    const margin = 8.0;
    double clampX(double v) =>
        v.clamp(margin, stackSize.width - bubbleSize.width - margin);
    double clampY(double v) =>
        v.clamp(margin, stackSize.height - bubbleSize.height - margin);

    final dx = clampX(baseLocal.dx);
    final dy = clampY(baseLocal.dy);

    if (!mounted) return;
    setState(() => _offset = Offset(dx, dy));
  }

  Future<void> _dismiss() async {
    try {
      await _controller.reverse();
    } finally {
      if (mounted) widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Version-agnostic clamped text scaling:
    final currentScale = MediaQuery.of(
      context,
    ).textScaler.scale(1.0); // -> double
    final clampedScale = currentScale.clamp(0.9, 1.4).toDouble();
    final clampedTextScaler = TextScaler.linear(clampedScale);

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: MediaQuery(
            // Constrain extreme system text scales for layout stability.
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: clampedTextScaler),
            child: Material(
              key: _bubbleKey,
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxWidth: 260),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      offset: Offset(0, 6),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: DefaultTextStyle(
                  style:
                      theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.surface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ) ??
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.message),
                      if (widget.showButton) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: TextButton(
                            onPressed: _dismiss,
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.surface,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            child: Text(t.gotIt),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
