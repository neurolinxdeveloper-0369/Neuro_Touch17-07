import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Central typography system using Google Fonts Inter.
/// Provides Material 3 text styles and adaptive helpers.
class AppTypography {
  AppTypography._();

  // ─── Base font ────────────────────────────────────────────────────────────
  static TextStyle _inter({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    Color? color,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );

  // ─── Display ──────────────────────────────────────────────────────────────
  static TextStyle get displayLarge => _inter(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        height: 1.12,
        letterSpacing: -0.25,
      );

  static TextStyle get displayMedium => _inter(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        height: 1.16,
      );

  static TextStyle get displaySmall => _inter(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        height: 1.22,
      );

  // ─── Headline ─────────────────────────────────────────────────────────────
  static TextStyle get headlineLarge => _inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );

  static TextStyle get headlineMedium => _inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.29,
      );

  static TextStyle get headlineSmall => _inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.33,
      );

  // ─── Title ────────────────────────────────────────────────────────────────
  static TextStyle get titleLarge => _inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.27,
      );

  static TextStyle get titleMedium => _inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
        letterSpacing: 0.15,
      );

  static TextStyle get titleSmall => _inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.1,
      );

  // ─── Body ─────────────────────────────────────────────────────────────────
  static TextStyle get bodyLarge => _inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.5,
      );

  static TextStyle get bodyMedium => _inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        letterSpacing: 0.25,
      );

  static TextStyle get bodySmall => _inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.33,
        letterSpacing: 0.4,
      );

  // ─── Label ────────────────────────────────────────────────────────────────
  static TextStyle get labelLarge => _inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.43,
        letterSpacing: 0.1,
      );

  static TextStyle get labelMedium => _inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.33,
        letterSpacing: 0.5,
      );

  static TextStyle get labelSmall => _inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.45,
        letterSpacing: 0.5,
      );

  // ─── Adaptive colour helpers ───────────────────────────────────────────────
  static TextStyle darkPrimary(TextStyle style) =>
      style.copyWith(color: AppColors.darkTextPrimary);

  static TextStyle darkSecondary(TextStyle style) =>
      style.copyWith(color: AppColors.darkTextSecondary);

  static TextStyle lightPrimary(TextStyle style) =>
      style.copyWith(color: AppColors.lightTextPrimary);

  static TextStyle lightSecondary(TextStyle style) =>
      style.copyWith(color: AppColors.lightTextSecondary);

  static TextStyle withColor(TextStyle style, Color color) =>
      style.copyWith(color: color);

  // ─── Full TextTheme (dark) ────────────────────────────────────────────────
  static TextTheme get darkTextTheme => TextTheme(
        displayLarge: darkPrimary(displayLarge),
        displayMedium: darkPrimary(displayMedium),
        displaySmall: darkPrimary(displaySmall),
        headlineLarge: darkPrimary(headlineLarge),
        headlineMedium: darkPrimary(headlineMedium),
        headlineSmall: darkPrimary(headlineSmall),
        titleLarge: darkPrimary(titleLarge),
        titleMedium: darkPrimary(titleMedium),
        titleSmall: darkSecondary(titleSmall),
        bodyLarge: darkPrimary(bodyLarge),
        bodyMedium: darkSecondary(bodyMedium),
        bodySmall: darkSecondary(bodySmall),
        labelLarge: darkPrimary(labelLarge),
        labelMedium: darkSecondary(labelMedium),
        labelSmall: darkSecondary(labelSmall),
      );

  // ─── Full TextTheme (light) ────────────────────────────────────────────────
  static TextTheme get lightTextTheme => TextTheme(
        displayLarge: lightPrimary(displayLarge),
        displayMedium: lightPrimary(displayMedium),
        displaySmall: lightPrimary(displaySmall),
        headlineLarge: lightPrimary(headlineLarge),
        headlineMedium: lightPrimary(headlineMedium),
        headlineSmall: lightPrimary(headlineSmall),
        titleLarge: lightPrimary(titleLarge),
        titleMedium: lightPrimary(titleMedium),
        titleSmall: lightSecondary(titleSmall),
        bodyLarge: lightPrimary(bodyLarge),
        bodyMedium: lightSecondary(bodyMedium),
        bodySmall: lightSecondary(bodySmall),
        labelLarge: lightPrimary(labelLarge),
        labelMedium: lightSecondary(labelMedium),
        labelSmall: lightSecondary(labelSmall),
      );
}
