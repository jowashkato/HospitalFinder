// lib/app_theme.dart
import 'package:flutter/material.dart';

/// Central colour + theme definitions.
///
/// Redesign direction: "vibrant care" — a bold violet gradient header, solid
/// candy-coloured category tiles with white glyphs, soft lavender accent cards,
/// rounded surfaces and gentle shadows on a near-white canvas.
class AppColors {
  AppColors._();

  // Brand — vivid violet
  static const Color primary = Color(0xFF6D3BE4);
  static const Color primaryDark = Color(0xFF5426C9);
  static const Color primaryLight = Color(0xFF9B6BF2);

  // Header gradient stops (top-left -> bottom-right)
  static const Color headerGradientStart = Color(0xFF5A2FE0);
  static const Color headerGradientEnd = Color(0xFF7C4DEE);

  // Surfaces
  static const Color scaffold = Color(0xFFF6F5FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color headerBg = Color(0xFF6D3BE4);
  static const Color border = Color(0xFFECEAF3);
  static const Color cardShadow = Color(0x14231147);

  // Text
  static const Color textPrimary = Color(0xFF1B1830);
  static const Color textSecondary = Color(0xFF8A8699);

  // Accents
  static const Color tipCardBg = Color(0xFFEDEBFF);
  static const Color tipAccent = Color(0xFF6E7DE8);

  static const Color openBg = Color(0xFFDDF6E7);
  static const Color openText = Color(0xFF15803D);

  static const Color star = Color(0xFFF5A524);

  // Category tile fills (rendered as solid rounded squares w/ white icons)
  static const Color catHospitals = Color(0xFF5B57D8);
  static const Color catServices = Color(0xFF22C55E);
  static const Color catDoctors = Color(0xFFC42EC7);
  static const Color catTips = Color(0xFFF97316);

  /// Violet header gradient used behind the greeting + search block.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [headerGradientStart, headerGradientEnd],
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    scaffoldBackgroundColor: AppColors.scaffold,
    fontFamily: 'Roboto',
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
  );
}
