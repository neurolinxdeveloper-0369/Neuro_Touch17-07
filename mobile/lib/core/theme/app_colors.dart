import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core background colors (1st color of each theme)
  static const Color darkBg = Color(0xFF000000);
  static const Color lightBg = Color(0xFFEAFBFF);
  
  // Cards background for both themes (2nd color)
  static const Color primaryCard = Color(0xFF06457F);
  
  // Foreground / Text / Icons / Primary branding (3rd color)
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color lightTextOnBg = Color(0xFF06457F);
  static const Color lightTextOnCard = Color(0xFFFFFFFF);

  // Helper mappings:
  static const Color darkBgColor = darkBg;
  static const Color lightBgColor = lightBg;
  
  static const Color cardDark = primaryCard;
  static const Color cardLight = primaryCard;
  
  // Borders
  static const Color borderDark = Color(0xFF06457F);
  static const Color borderLight = Color(0xFF06457F);

  // Text
  static const Color darkTextPrimary = darkText;
  static const Color darkTextSecondary = darkText;
  
  static const Color lightTextPrimary = lightTextOnBg;
  static const Color lightTextSecondary = lightTextOnBg;

  // Brand colors
  static const Color primary = Color(0xFF06457F);
  static const Color secondary = Color(0xFF06457F);
  static const Color surface = Color(0xFF06457F);
  
  static const Color success = Color(0xFF06457F);
  static const Color warning = Color(0xFF06457F);
  static const Color error = Color(0xFF06457F);
  static const Color info = Color(0xFF06457F);
  
  static const Color online = Color(0xFFFFFFFF);
  static const Color offline = Color(0xFF000000);

  // Shimmer
  static Color shimmerBaseColor(bool isDark) =>
      isDark ? const Color(0xFF000000) : const Color(0xFFEAFBFF);
  
  static Color shimmerHighlightColor(bool isDark) =>
      isDark ? const Color(0xFF06457F) : const Color(0xFF06457F);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primary],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [primary, primary],
  );

  // Adaptive helpers
  static Color textPrimary(bool isDark) =>
      isDark ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(bool isDark) =>
      isDark ? darkTextSecondary : lightTextSecondary;

  static Color cardColor(bool isDark) => isDark ? cardDark : cardLight;

  static Color borderColor(bool isDark) => isDark ? borderDark : borderLight;

  static Color backgroundColor(bool isDark) => isDark ? darkBg : lightBg;
}
