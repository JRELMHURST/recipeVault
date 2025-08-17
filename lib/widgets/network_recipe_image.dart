// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NetworkRecipeImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  final String? heroTag;
  final Duration fadeInDuration;

  const NetworkRecipeImage({
    super.key,
    required this.imageUrl,
    this.width = 64,
    this.height = 64,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.fit = BoxFit.cover,
    this.onTap,
    this.semanticsLabel,
    this.heroTag,
    this.fadeInDuration = const Duration(milliseconds: 180),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = imageUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;

    final img = _buildImage(context, theme, url, hasUrl);
    final clipped = ClipRRect(borderRadius: borderRadius, child: img);
    final wrapped = heroTag != null
        ? Hero(tag: heroTag!, child: clipped)
        : clipped;

    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      image: true,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              splashFactory: InkSplash.splashFactory,
              child: wrapped,
            )
          : wrapped,
    );
  }

  Widget _buildImage(
    BuildContext context,
    ThemeData theme,
    String? url,
    bool hasUrl,
  ) {
    if (!hasUrl) {
      return _placeholderBox(
        theme,
        showSpinner: false,
        icon: Icons.image_outlined,
      );
    }

    // DPR-aware cache sizing to balance sharpness and memory.
    MediaQuery.of(
      context,
    ).textScaler.scale(1.0); // stable factor we already clamp elsewhere
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final dpr = devicePixelRatio.clamp(1.0, 3.0);
    final memW = (width * dpr).round();
    final memH = (height * dpr).round();

    return CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memW,
      memCacheHeight: memH,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholderFadeInDuration: const Duration(milliseconds: 120),
      filterQuality: FilterQuality.medium,
      placeholder: (context, _) =>
          _placeholderBox(theme, showSpinner: true, icon: Icons.image_outlined),
      errorWidget: (context, _, __) => _placeholderBox(
        theme,
        showSpinner: false,
        icon: Icons.broken_image_outlined,
      ),
    );
  }

  Widget _placeholderBox(
    ThemeData theme, {
    required bool showSpinner,
    required IconData icon,
  }) {
    final bg = theme.colorScheme.surfaceContainerHighest.withOpacity(0.4);
    final fg = theme.colorScheme.onSurfaceVariant.withOpacity(0.6);

    return Container(
      width: width,
      height: height,
      color: bg,
      alignment: Alignment.center,
      child: showSpinner
          ? SizedBox(
              width: math.max(20, width * 0.25),
              height: math.max(20, height * 0.25),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            )
          : Icon(icon, size: math.min(width, height) * 0.45, color: fg),
    );
  }
}
