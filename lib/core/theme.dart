// lib/core/theme.dart
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
  static const Color primaryColor = Color(0xFF77528D); // unified purple
  static const Color loginBackground = Color(0xFFF3EEFF); // soft lavender
  static const Color backgroundLight = loginBackground;
  static const Color backgroundDark = Color(0xFF17141E);

  static AppBarTheme buildAppBarTheme(Color backgroundColor) {
    return AppBarTheme(
      backgroundColor: backgroundColor,
      surfaceTintColor: backgroundColor,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      foregroundColor: Colors.white,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.raleway(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 1.2,
      ),
    );
  }

  // ---- LIGHT ----
  static final ThemeData lightTheme = _buildTheme(
    brightness: Brightness.light,
    baseBg: backgroundLight,
    seed: primaryColor,
    appBarBg: primaryColor,
  );

  // ---- DARK ----
  static final ThemeData darkTheme = _buildTheme(
    brightness: Brightness.dark,
    baseBg: backgroundDark,
    seed: primaryColor,
    appBarBg: primaryColor,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color baseBg,
    required Color seed,
    required Color appBarBg,
  }) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: seed,
      surface: isDark ? const Color(0xFF1E1B26) : Colors.white,
      background: baseBg,
    );

    final textTheme = GoogleFonts.ralewayTextTheme().copyWith(
      titleLarge: GoogleFonts.raleway(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: seed,
      ),
      titleMedium: GoogleFonts.raleway(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87,
      ),
      bodyMedium: GoogleFonts.raleway(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: baseBg,
      fontFamily: GoogleFonts.raleway().fontFamily,

      // AppBar
      appBarTheme: buildAppBarTheme(appBarBg),

      // ✅ CardThemeData (SDK expects *Data* type)
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF23202A) : Colors.white,
        elevation: 6,
        margin: EdgeInsets.symmetric(
          vertical: isDark ? 18 : 12,
          horizontal: isDark ? 18 : 20,
        ),
        shadowColor: isDark
            ? const Color(0x77000000)
            : Colors.black.withOpacity(0.05),
        shape: isDark
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                side: BorderSide(color: AppTheme.primaryColor, width: 1.3),
              )
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.raleway(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : seed,
          side: BorderSide(color: isDark ? Colors.white70 : seed),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: GoogleFonts.raleway(fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.raleway(fontWeight: FontWeight.w600),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1B26) : const Color(0xFFF7F4FB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? const Color(0xFF23202A)
            : const Color(0xFFF1ECFF),
        selectedColor: scheme.primary.withOpacity(0.15),
        labelStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontFamily: GoogleFonts.raleway().fontFamily,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: scheme.primary,
          fontFamily: GoogleFonts.raleway().fontFamily,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(
          color: isDark ? const Color(0xFF383345) : scheme.outlineVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Snackbars
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF23202A) : Colors.black87,
        contentTextStyle: GoogleFonts.raleway(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ✅ DialogThemeData (SDK expects *Data* type)
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF23202A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF23202A) : Colors.white,
        surfaceTintColor: isDark ? const Color(0xFF23202A) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.6),
        thickness: 1,
        space: 1,
      ),

      textTheme: textTheme,
      iconTheme: IconThemeData(color: isDark ? Colors.white70 : Colors.black87),
    );
  }
}
