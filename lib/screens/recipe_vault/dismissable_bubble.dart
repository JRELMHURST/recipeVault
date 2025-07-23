import 'package:flutter/material.dart';

class DismissibleBubble extends StatefulWidget {
  final String message;
  final Offset position;
  final VoidCallback onDismiss;

  const DismissibleBubble({
    super.key,
    required this.message,
    required this.position,
    required this.onDismiss,
  });

  @override
  State<DismissibleBubble> createState() => _DismissibleBubbleState();
}

class _DismissibleBubbleState extends State<DismissibleBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

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

    _controller.forward();
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
    return Positioned(
      top: widget.position.dy,
      left: widget.position.dx,
      child: GestureDetector(
        onTap: _handleDismiss,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(14),
                constraints: const BoxConstraints(maxWidth: 240),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.black87, Colors.black],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 10,
                      offset: Offset(0, 6),
                      color: Colors.black54,
                    ),
                  ],
                ),
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
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
