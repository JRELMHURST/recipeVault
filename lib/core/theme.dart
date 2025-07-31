// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColours {
  static const turquoise = Color(0xFF3CCFBD);
  static const lavender = Color(0xFFA593E0);
  static const coral = Color(0xFFFF6B6B);
  static const lemon = Color(0xFFFFD93D);
  static const mint = Color(0xFF7DDE92);
  static const steel = Color(0xFF6C7A89);
}

class AppTheme {
  static const Color primaryColor = Color(0xFF77528D); // Unified theme purple
  static const Color loginBackground = Color(0xFFF3EEFF); // Soft lavender
  static const Color backgroundLight = loginBackground;
  static const Color backgroundDark = Color(0xFF17141E);

  static AppBarTheme buildAppBarTheme(Color backgroundColor) {
    return AppBarTheme(
      backgroundColor: backgroundColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.raleway(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 1.2,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      surface: Colors.white,
      surfaceContainerHighest: Color(0xFFF7F4FB),
    ),
    fontFamily: GoogleFonts.raleway().fontFamily,
    appBarTheme: buildAppBarTheme(primaryColor),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      shadowColor: Colors.black.withOpacity(0.05),
    ),
    textTheme: TextTheme(
      titleLarge: GoogleFonts.raleway(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: primaryColor,
      ),
      titleMedium: GoogleFonts.raleway(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      bodyMedium: GoogleFonts.raleway(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Colors.black87,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.raleway(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: GoogleFonts.raleway(fontWeight: FontWeight.w500),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      surface: Color(0xFF1E1B26),
      surfaceContainerHighest: Color(0xFF272333),
    ),
    fontFamily: GoogleFonts.raleway().fontFamily,
    appBarTheme: buildAppBarTheme(primaryColor),
    cardTheme: CardThemeData(
      color: const Color(0xFF23202A),
      elevation: 6,
      margin: const EdgeInsets.all(18),
      shadowColor: const Color(0x77000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: AppTheme.primaryColor, width: 1.3),
      ),
    ),
    textTheme: TextTheme(
      titleLarge: GoogleFonts.raleway(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: primaryColor,
      ),
      titleMedium: GoogleFonts.raleway(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      bodyMedium: GoogleFonts.raleway(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Colors.white70,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.raleway(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: GoogleFonts.raleway(fontWeight: FontWeight.w500),
      ),
    ),
  );
}
