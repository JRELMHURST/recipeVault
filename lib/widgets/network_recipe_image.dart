import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NetworkRecipeImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const NetworkRecipeImage({
    super.key,
    required this.imageUrl,
    this.width = 64,
    this.height = 64,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade300,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
        ),
      ),
    );
  }
}
