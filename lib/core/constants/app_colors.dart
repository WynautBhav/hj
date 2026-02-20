import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

class AppColors {
  static const Color scaffold     = Color(0xFFF8F5FF);
  static const Color primary      = Color(0xFFFFFFFF);
  static const Color cardBg       = Color(0xFFFFFFFF);
  static const Color secondary    = Color(0xFFEDE8FB);
  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B7B);
  static const Color divider       = Color(0xFFE8E0F0);
  static const Color accent        = Color(0xFF7C5FD6);
  static const Color accentLight   = Color(0xFFEDE8FB);
  static const Color accentDark    = Color(0xFF5B3CC4);
  static const Color sosRed        = Color(0xFFE53935);
  static const Color sosRedLight   = Color(0xFFFFEBEB);
  static const Color safeGreen     = Color(0xFF34C759);
  static const Color warning       = Color(0xFFF5A623);
  static const Color warningLight  = Color(0xFFFFF3E0);
  static const Color error         = Color(0xFFE53935);
  static const Color success       = Color(0xFF43A047);
  static const Color iconColor     = Color(0xFF1A1A2E);
  static const Color cardBackground = Color(0xFFFFFFFF);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: scaffold,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: secondary,
        surface: primary,
        error: error,
        onPrimary: primary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        outline: divider,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: divider),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w300,
          color: textPrimary, letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary,
        ),
      ),
    );
  }
}
