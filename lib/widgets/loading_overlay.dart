import 'package:flutter/material.dart';

class LoadingOverlay {
  static final GlobalKey<_OverlayLoaderState> _key =
      GlobalKey<_OverlayLoaderState>();
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(builder: (_) => _OverlayLoader(key: _key));

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  static void hide() {
    _key.currentState?.hide();
  }

  static void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _OverlayLoader extends StatefulWidget {
  const _OverlayLoader({super.key});

  @override
  State<_OverlayLoader> createState() => _OverlayLoaderState();
}

class _OverlayLoaderState extends State<_OverlayLoader>
    with SingleTickerProviderStateMixin {
  bool _visible = true;

  void hide() {
    setState(() => _visible = false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) LoadingOverlay._removeOverlay();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
