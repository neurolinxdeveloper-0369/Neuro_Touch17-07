import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core backgrounds
  static const Color darkBg = Color(0xFF010817);
  static const Color lightBg = Color(0xFFF2F3F5);
  static const Color surface = Color(0xFFE2E4E8); // Light grey/blue surface

  // Brand colors
  static const Color primary = Color(0xFF4C6FFF);
  static const Color secondary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFF7B97FF);

  // Semantic colors
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color error = Color(0xFFE17055);
  static const Color info = Color(0xFF74B9FF);

  // Text colors
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB2BEC3);
  static const Color lightTextPrimary = Color(0xFF0F172A); // Lighter dark-navy for contrast
  static const Color lightTextSecondary = Color(0xFF555E68);

  // Card colors
  static const Color cardDark = Color(0xFF45484D);
  static const Color cardLight = Color(0xFF194B85);

  // Border colors
  static const Color borderDark = Color(0xFF55595E);
  static const Color borderLight = Color(0xFFD1D5DB);

  // Shimmer (adaptive helper methods instead of constants)
  static Color shimmerBaseColor(bool isDark) =>
      isDark ? const Color(0xFF2C2E30) : const Color(0xFF153B6A);
  
  static Color shimmerHighlightColor(bool isDark) =>
      isDark ? const Color(0xFF45484D) : const Color(0xFF194B85);

  // Online/offline
  static const Color online = Color(0xFF00B894);
  static const Color offline = Color(0xFF555E68);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF45484D), Color(0xFF010817)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
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
