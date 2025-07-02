// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:go_router/go_router.dart';

import 'package:recipe_vault/widgets/dev_bypass_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 800),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  Future<void> _startProcessingFlow() async {
    setState(() => _isLoading = true);

    try {
      final compressedFiles =
          await ImageProcessingService.pickAndCompressImages();

      setState(() => _isLoading = false);

      if (compressedFiles.isEmpty) {
        _showError('No images selected or failed to compress.');
        return;
      }

      if (!mounted) return;

      ProcessingOverlay.show(context, compressedFiles);
    } catch (e) {
      debugPrint('Image processing failed: $e');
      _showError('Something went wrong.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE6E2FF), Color(0xFFF7F4FB)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _controller,
                    curve: Curves.easeOut,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Image.asset(
                          'assets/icon/round_vaultLogo.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Text(
                        'RecipeVault',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Less faff, more flavour.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          color: theme.colorScheme.primary.withOpacity(0.75),
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.0,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Effortlessly turn screenshots into\ndelicious, shareable recipe cards.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 17,
                          height: 1.5,
                          color: theme.colorScheme.onSurface.withOpacity(0.72),
                        ),
                      ),
                      const SizedBox(height: 42),
                      _BouncyButton(
                        onPressed: _startProcessingFlow,
                        label: 'Generate Recipe Card',
                        icon: Icons.camera_alt_rounded,
                        color: theme.colorScheme.primary,
                        textColor: Colors.white,
                      ),
                      const SizedBox(height: 18),
                      // 👇 DEV BYPASS BUTTON
                      const DevBypassButton(),
                      const SizedBox(height: 12),
                      Text(
                        'No faff. No ads. Just recipes.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isLoading) const LoadingOverlay(),
      ],
    );
  }
}

// --- Place this at the bottom of the file if not already ---
class _BouncyButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;

  const _BouncyButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  State<_BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<_BouncyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 140),
    lowerBound: 0.0,
    upperBound: 0.08,
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() async {
    await _controller.forward();
    await _controller.reverse();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: [
        widget.color,
        widget.color.withOpacity(0.92),
        Colors.deepPurpleAccent.withOpacity(0.7),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(scale: 1 - _controller.value, child: child);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.28),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: null, // All tap handled by parent GestureDetector
            icon: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 1.12),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              builder: (context, scale, icon) {
                return Transform.scale(
                  scale: scale - (_controller.value * 0.06),
                  child: icon,
                );
              },
              child: Icon(widget.icon, size: 26, color: widget.textColor),
            ),
            label: Text(
              widget.label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: widget.textColor,
                shadows: [
                  Shadow(
                    blurRadius: 6,
                    color: Colors.black26,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: widget.textColor,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
