import 'package:flutter/material.dart';
import 'dart:ui';
import 'constants.dart';

class AppTheme {
  static ThemeData get retroTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.accentCoral,
      scaffoldBackgroundColor: AppColors.bgCream,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentCoral,
        secondary: AppColors.panelDark,
        surface: AppColors.bgCream,
        error: Colors.redAccent,
      ),
      fontFamily: 'Outfit', // A modern geometric sans-serif style font, fallbacks will apply
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark, letterSpacing: -0.5),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textDark),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textDark),
        bodyLarge: TextStyle(fontSize: 15, color: AppColors.textDark, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textMutedDark, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9F9FB), // Clean layout grey input background
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderBlack, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderBlack, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accentCoral, width: 2.0),
        ),
        hintStyle: const TextStyle(color: AppColors.textMutedLight, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textDark),
      ),
    );
  }

  // Reusable panel decoration
  static BoxDecoration glassDecoration({
    double borderRadius = 20.0,
    bool isHovered = false,
    bool hasGlow = false,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? (isHovered ? AppColors.panelSlate : AppColors.panelDark),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: AppColors.borderBlack,
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isHovered ? 0.08 : 0.04),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // Reusable panel wrapper (keeps legacy name for compatibility)
  static Widget glassmorphismPanel({
    required Widget child,
    double blurX = 8.0,
    double blurY = 8.0,
    double borderRadius = 20.0,
    bool isHovered = false,
    bool hasGlow = false,
    EdgeInsetsGeometry? padding,
    Color? color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
        child: Container(
          padding: padding,
          decoration: glassDecoration(
            borderRadius: borderRadius,
            isHovered: isHovered,
            hasGlow: hasGlow,
            color: color,
          ),
          child: child,
        ),
      ),
    );
  }
}
