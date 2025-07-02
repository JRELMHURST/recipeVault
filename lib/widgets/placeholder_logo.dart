import 'package:flutter/material.dart';

class PlaceholderLogo extends StatelessWidget {
  final String imageAsset;

  const PlaceholderLogo({super.key, required this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        imageAsset,
        width: 120,
        height: 120,
        fit: BoxFit.contain,
      ),
    );
  }
}
