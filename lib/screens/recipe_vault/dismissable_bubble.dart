// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class DismissibleBubble extends StatefulWidget {
  final String message;

  /// Absolute position (in global coordinates) fallback if no anchorKey is provided.
  final Offset? position;

  /// Anchor widget to position the bubble near. If provided, we’ll place the bubble
  /// just below the anchor with a small gap.
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

  // Where we’ll place the bubble (in this Stack’s coordinate space)
  Offset _offset = const Offset(16, 80);

  // We measure our own size so clamping is accurate
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

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Initial position after first layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculatePosition();
      _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant DismissibleBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchorKey != widget.anchorKey ||
        oldWidget.position != widget.position) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _recalculatePosition(),
      );
    }
  }

  @override
  void didChangeMetrics() {
    // Orientation/keyboard/safe-area changes → reposition
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculatePosition());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _recalculatePosition() async {
    final stackBox = context.findRenderObject() as RenderBox?;
    if (stackBox == null || !mounted) return;

    // 1) Determine a base *global* position
    Offset baseGlobal;
    double belowGap = 8.0;

    if (widget.anchorKey?.currentContext != null) {
      final anchorBox =
          widget.anchorKey!.currentContext!.findRenderObject() as RenderBox?;
      if (anchorBox != null) {
        final anchorTopLeft = anchorBox.localToGlobal(Offset.zero);
        baseGlobal = anchorTopLeft;
        belowGap += anchorBox.size.height; // drop just below the anchor
      } else {
        baseGlobal = widget.position ?? const Offset(16, 80);
      }
    } else {
      baseGlobal = widget.position ?? const Offset(16, 80);
    }

    // 2) Convert to this Stack’s local coordinates and add the gap
    final baseLocal = stackBox.globalToLocal(baseGlobal) + Offset(0, belowGap);

    // 3) Measure our own size (fallback to reasonable default)
    final Size bubbleSize =
        (_bubbleKey.currentContext?.findRenderObject() as RenderBox?)?.size ??
        const Size(240, 80);

    final Size stackSize = stackBox.size;

    // 4) Clamp inside the visible area of this Stack
    final double margin = 8.0;
    final dx = baseLocal.dx.clamp(
      margin,
      stackSize.width - bubbleSize.width - margin,
    );
    final dy = baseLocal.dy.clamp(
      margin,
      stackSize.height - bubbleSize.height - margin,
    );

    setState(() => _offset = Offset(dx.toDouble(), dy.toDouble()));
  }

  void _dismiss() {
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            key: _bubbleKey,
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxWidth: 260),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.88),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
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
                            foregroundColor: Colors.white,
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
    );
  }
}
