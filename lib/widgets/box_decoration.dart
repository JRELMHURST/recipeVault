// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

BoxDecoration whiteGlowDecoration(Color backgroundColor) {
  return BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.white.withOpacity(0.6),
        blurRadius: 12,
        spreadRadius: 0.5,
        offset: const Offset(0, 0),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
