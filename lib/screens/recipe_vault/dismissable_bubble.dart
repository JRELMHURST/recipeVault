import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class DismissibleBubble extends StatefulWidget {
  final String message;
  final Offset? position; // Now optional
  final GlobalKey? anchorKey; // 👈 new
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  Offset _calculatedOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _calculateAnchorPosition(),
    );
    _controller.forward();
  }

  void _calculateAnchorPosition() {
    if (widget.anchorKey?.currentContext != null) {
      final renderBox =
          widget.anchorKey!.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      setState(() {
        _calculatedOffset = position.translate(
          0,
          renderBox.size.height + 8,
        ); // 8px gap
      });
    } else if (widget.position != null) {
      _calculatedOffset = widget.position!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      top: _calculatedOffset.dy,
      left: _calculatedOffset.dx,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxWidth: 240),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 10,
                    offset: Offset(0, 4),
                    color: Colors.black38,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  if (widget.showButton) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: TextButton(
                        onPressed: _handleDismiss,
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
                        child: Text(l10n.gotIt),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
