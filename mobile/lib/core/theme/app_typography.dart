import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle _inter({
    required double fontSize,
    required FontWeight fontWeight,
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

  // Headlines
  static TextStyle get h1 => _inter(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static TextStyle get h2 => _inter(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3);
  static TextStyle get h3 => _inter(fontSize: 20, fontWeight: FontWeight.w600);

  // Body
  static TextStyle get bodyLarge => _inter(fontSize: 16, fontWeight: FontWeight.w400);
  static TextStyle get bodyMedium => _inter(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle get bodySmall => _inter(fontSize: 12, fontWeight: FontWeight.w400);

  // Compatibility titles
  static TextStyle get titleLarge => h3;
  static TextStyle get titleMedium => _inter(fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle get titleSmall => _inter(fontSize: 14, fontWeight: FontWeight.w600);

  // Special
  static TextStyle get label => _inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5);
  static TextStyle get button => _inter(fontSize: 16, fontWeight: FontWeight.w600);

  // Adaptive Helpers
  static TextTheme get darkTextTheme => TextTheme(
        headlineLarge: h1.copyWith(color: AppColors.darkTextPrimary),
        headlineMedium: h2.copyWith(color: AppColors.darkTextPrimary),
        titleLarge: h3.copyWith(color: AppColors.darkTextPrimary),
        bodyLarge: bodyLarge.copyWith(color: AppColors.darkTextPrimary),
        bodyMedium: bodyMedium.copyWith(color: AppColors.darkTextSecondary),
        bodySmall: bodySmall.copyWith(color: AppColors.darkTextSecondary),
        labelLarge: label.copyWith(color: AppColors.darkTextPrimary),
      );

  static TextTheme get lightTextTheme => TextTheme(
        headlineLarge: h1.copyWith(color: AppColors.lightTextPrimary),
        headlineMedium: h2.copyWith(color: AppColors.lightTextPrimary),
        titleLarge: h3.copyWith(color: AppColors.lightTextPrimary),
        bodyLarge: bodyLarge.copyWith(color: AppColors.lightTextPrimary),
        bodyMedium: bodyMedium.copyWith(color: AppColors.lightTextSecondary),
        bodySmall: bodySmall.copyWith(color: AppColors.lightTextSecondary),
        labelLarge: label.copyWith(color: AppColors.lightTextPrimary),
      );
}
