// daily_tip_banner_controller.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class DailyTipBannerController {
  OverlayEntry? _entry;
  AnimationController? _anim;
  Timer? _autoClose;
  bool _inFlight = false;

  bool get isShowing => _entry != null;

  Future<void> show({
    required BuildContext context,
    required TickerProvider vsync,
    required Widget content,
    Duration inDuration = const Duration(milliseconds: 260),
    Duration outDuration = const Duration(milliseconds: 180),
    Duration? autoCloseAfter = const Duration(seconds: 6),
    // ── Scrim controls (off by default) ────────────────────────────────────
    bool enableScrim = false,
    Color scrimColor = const Color(0x14000000),
    // ── Layout ─────────────────────────────────────────────────────────────
    double maxWidth = 480,
    double radius = 20,
    double topMargin = kToolbarHeight + 12,
  }) async {
    if (_inFlight) return;
    _inFlight = true;

    try {
      // Clean up anything already showing
      await close(immediate: true);

      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;

      _anim = AnimationController(
        vsync: vsync,
        duration: inDuration,
        reverseDuration: outDuration,
      );

      final curved = CurvedAnimation(
        parent: _anim!,
        curve: Curves.easeOutCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, -0.06),
        end: Offset.zero,
      ).animate(curved);
      final scale = Tween<double>(begin: 0.985, end: 1).animate(curved);
      final fade = curved;

      Future<void> closeInternal({bool immediate = false}) async {
        _autoClose?.cancel();
        _autoClose = null;

        final anim = _anim;
        final entry = _entry;
        _anim = null;
        _entry = null;

        if (immediate) {
          try {
            anim?.stop();
          } catch (_) {}
          try {
            anim?.dispose();
          } catch (_) {}
          try {
            entry?.remove();
          } catch (_) {}
          return;
        }

        try {
          if (anim != null && anim.status != AnimationStatus.dismissed) {
            await anim.reverse();
          }
        } catch (_) {}
        try {
          anim?.dispose();
        } catch (_) {}
        try {
          entry?.remove();
        } catch (_) {}
      }

      _entry = OverlayEntry(
        builder: (ctx) {
          final sysTop = MediaQuery.of(ctx).padding.top;
          final double padTop = math.max(sysTop + topMargin, 0.0);

          return Positioned.fill(
            child: Stack(
              children: [
                if (enableScrim)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => closeInternal(),
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(radius),
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
      await _anim!.forward();

      if (autoCloseAfter != null) {
        _autoClose = Timer(autoCloseAfter, () {
          // ignore: discarded_futures
          closeInternal();
        });
      }
    } finally {
      _inFlight = false;
    }
  }

  Future<void> close({bool immediate = false}) async {
    if (_entry == null && _anim == null) return;

    _autoClose?.cancel();
    _autoClose = null;

    final anim = _anim;
    final entry = _entry;
    _anim = null;
    _entry = null;

    if (immediate) {
      try {
        anim?.stop();
      } catch (_) {}
      try {
        anim?.dispose();
      } catch (_) {}
      try {
        entry?.remove();
      } catch (_) {}
      return;
    }

    try {
      if (anim != null && anim.status != AnimationStatus.dismissed) {
        await anim.reverse();
      }
    } catch (_) {}
    try {
      anim?.dispose();
    } catch (_) {}
    try {
      entry?.remove();
    } catch (_) {}
  }

  Future<void> dispose() async => close(immediate: true);
}
