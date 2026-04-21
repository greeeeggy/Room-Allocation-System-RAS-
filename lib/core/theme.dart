import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Status colors
  static const Color available = Color(0xFF81C784);   // green
  static const Color occupied  = Color(0xFFE57373);   // red
  static const Color soon      = Color(0xFFFFB74D);   // amber

  // Brand
  static const Color primary   = Color(0xFF1565C0);   // deep blue
  static const Color accent    = Color(0xFF26A69A);   // stylish mint/teal
  static const Color surface   = Color(0xFFF5F7FA);
  static const Color card      = Color(0xFFFFFFFF);

  // Glassmorphism
  static const Color glassBackground = Color(0x33FFFFFF); // white with 20% opacity
  static const Color glassBorder     = Color(0x33FFFFFF); // white with 20% opacity for borders

  // Text
  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
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
