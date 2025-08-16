// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class DailyTipBannerController {
  OverlayEntry? _entry;
  AnimationController? _anim;
  Timer? _autoClose;
  bool _isShowing = false;

  bool get isShowing => _isShowing;

  Future<void> show({
    required BuildContext context,
    required TickerProvider vsync,
    required Widget content,
    Duration inDuration = const Duration(milliseconds: 260),
    Duration outDuration = const Duration(milliseconds: 180),
    Duration? autoCloseAfter = const Duration(seconds: 6),
    Color scrimColor = const Color(0x14000000), // subtle ~8% black
    double maxWidth = 480,
    double radius = 20,
    double topMargin = kToolbarHeight + 12, // ⬅️ opens lower (below AppBar)
  }) async {
    // Close any existing instance first so a tap always shows a fresh one
    await close();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _anim = AnimationController(
      vsync: vsync,
      duration: inDuration,
      reverseDuration: outDuration,
    );

    final curved = CurvedAnimation(parent: _anim!, curve: Curves.easeOutCubic);
    final slide = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(curved);
    final fade = curved;
    final scale = Tween<double>(begin: 0.985, end: 1).animate(curved);

    Future<void> closeInternal() async {
      _autoClose?.cancel();
      try {
        if (_anim != null && _anim!.status != AnimationStatus.dismissed) {
          await _anim!.reverse();
        }
      } catch (_) {}
      try {
        _anim?.dispose();
      } catch (_) {}
      _anim = null;

      _entry?.remove();
      _entry = null;
      _isShowing = false;
    }

    _entry = OverlayEntry(
      builder: (ctx) {
        final sysTop = MediaQuery.of(ctx).padding.top;
        final double padTop = math.max(sysTop + topMargin, 0).toDouble();
        return Positioned.fill(
          child: Stack(
            children: [
              // Subtle scrim; tap outside to close
              Positioned.fill(
                child: GestureDetector(
                  onTap: closeInternal,
                  child: ColoredBox(color: scrimColor),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FadeTransition(
                    opacity: fade,
                    child: SlideTransition(
                      position: slide,
                      child: ScaleTransition(
                        scale: scale,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: padTop,
                            left: 16,
                            right: 16,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: Material(
                              color: Theme.of(ctx).colorScheme.surface,
                              elevation: 22,
                              shadowColor: Colors.black.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(radius),
                              clipBehavior: Clip.antiAlias,
                              child: content,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(_entry!);
    _isShowing = true;
    await _anim!.forward();

    if (autoCloseAfter != null) {
      _autoClose = Timer(autoCloseAfter, () {
        // ignore: discarded_futures
        closeInternal();
      });
    }
  }

  Future<void> close() async {
    _autoClose?.cancel();
    _autoClose = null;
    try {
      if (_anim != null && _anim!.status != AnimationStatus.dismissed) {
        await _anim!.reverse();
      }
    } catch (_) {}
    try {
      _anim?.dispose();
    } catch (_) {}
    _anim = null;

    _entry?.remove();
    _entry = null;
    _isShowing = false;
  }

  Future<void> dispose() async => close();
}
