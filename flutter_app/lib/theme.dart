import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Foraging app design system.
/// Colors: forest green, warm bark, off-white, danger red.
/// Typography: DM Sans. Spacing: 4px base grid.
class ForageTheme {
  // Colors
  static const primary = Color(0xFF2D5016);
  static const primaryLight = Color(0xFF4A7A2E);
  static const secondary = Color(0xFF8B6914);
  static const background = Color(0xFFFAFAF5);
  static const surface = Color(0xFFFFFFFF);
  static const textColor = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF6B6B5E);
  static const danger = Color(0xFFB33A3A);
  static const dangerBg = Color(0xFFFDE8E8);

  // Confidence colors
  static const confHigh = Color(0xFF2D5016);
  static const confHighBg = Color(0xFFE8F0E4);
  static const confMed = Color(0xFF8B6914);
  static const confMedBg = Color(0xFFFFF3D6);
  static const confLow = Color(0xFFB33A3A);
  static const confLowBg = Color(0xFFFDE8E8);

  // Spacing (4px base grid)
  static const double sp4 = 4;
  static const double sp8 = 8;
  static const double sp12 = 12;
  static const double sp16 = 16;
  static const double sp24 = 24;
  static const double sp32 = 32;
  static const double sp48 = 48;

  static Color confidenceColor(String confidence) {
    switch (confidence) {
      case 'high':
        return confHigh;
      case 'medium':
        return confMed;
      case 'low':
        return confLow;
      default:
        return textMuted;
    }
  }

  static Color confidenceBgColor(String confidence) {
    switch (confidence) {
      case 'high':
        return confHighBg;
      case 'medium':
        return confMedBg;
      case 'low':
        return confLowBg;
      default:
        return background;
    }
  }

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: danger,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.dmSansTextTheme().apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFFE0DDD4)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
      ),
    );
  }
}
