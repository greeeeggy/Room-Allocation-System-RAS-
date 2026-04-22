import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Status colors
  static const Color available = Color(0xFF81C784);   // green
  static const Color occupied  = Color(0xFFE57373);   // red
  static const Color soon      = Color(0xFFFFB74D);   // amber

  // Brand — Red family palette
  static const Color primary       = Color(0xFF890620); // Burgundy
  static const Color primaryLight  = Color(0xFFB6465F); // Berry Crush
  static const Color primaryDark   = Color(0xFF2C0703); // Rich Mahogany
  static const Color accent        = Color(0xFFDA9F93); // Rosy Taupe
  static const Color surface       = Color(0xFFF5F0EE); // warm near-white (derived from Almond Silk)
  static const Color card          = Color(0xFFFFFFFF);

  // Auth screen specific
  static const Color authBackground    = Color(0xFF1A0408); // near-black with red undertone
  static const Color authGlow          = Color(0xFF890620); // Burgundy glow
  static const Color authSurface       = Color(0x1AFFFFFF); // glass white 10%
  static const Color authBorder        = Color(0x33EBD4CB); // Almond Silk at 20%

  // Glassmorphism
  static const Color glassBackground = Color(0x1AFFFFFF);
  static const Color glassBorder     = Color(0x33FFFFFF);

  // Text
  static const Color textPrimary   = Color(0xFF1A0408);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnDark    = Color(0xFFEBD4CB); // Almond Silk
}

class AppTheme {
  static ThemeData get light {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.surface,
      ),
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme),
      primaryTextTheme: GoogleFonts.outfitTextTheme(baseTheme.primaryTextTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.outfit(),
        hintStyle: GoogleFonts.outfit(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
