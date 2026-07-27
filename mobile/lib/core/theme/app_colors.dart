import 'package:flutter/material.dart';

/// Central color token system for Neuro Touch.
class AppColors {
  AppColors._();

  // ─── Brand Colors ─────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF06457F);
  static const Color primaryLight = Color(0xFF1B6FB8);
  static const Color primaryDeep = Color(0xFF03294D);

  // ─── Background ───────────────────────────────────────────────────────────
  static const Color bgDark = Color(0xFF121212);
  static const Color bgLight = Color(0xFFF3FAFC);

  // ─── Glass Surfaces ───────────────────────────────────────────────────────
  static Color glassDark(double opacity) => Colors.white.withValues(alpha: opacity);
  static Color glassLight(double opacity) => primary.withValues(alpha: opacity);

  // ─── Borders ──────────────────────────────────────────────────────────────
  static Color borderDark = Colors.white.withValues(alpha: 0.14);
  static Color borderLight = primary.withValues(alpha: 0.12);

  // ─── Text (Dark Mode) ─────────────────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFF5F8FA);
  static const Color darkTextSecondary = Colors.white70;

  // ─── Text (Light Mode) ────────────────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF0B2540);
  static const Color lightTextSecondary = Color(0xA606457F); // 65% primary

  // ─── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2FBF83);
  static const Color warning = Color(0xFFE8A93B);
  static const Color error = Color(0xFFE5484D);
  static const Color info = primaryLight;

  // ─── Adaptive Helpers ─────────────────────────────────────────────────────
  static Color textPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color scaffoldBackground(bool isDark) => isDark ? bgDark : bgLight;
  static Color cardBackground(bool isDark) => isDark ? glassDark(0.08) : glassLight(0.06);
  static Color borderColor(bool isDark) => isDark ? borderDark : borderLight;

  // ─── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient glassGradient(bool isDark) => LinearGradient(
        colors: [
          isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.6),
          isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.3),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
