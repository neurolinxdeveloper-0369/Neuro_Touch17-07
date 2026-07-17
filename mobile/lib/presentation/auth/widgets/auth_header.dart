import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _primary = Color(0xFF06457F);
const Color _secondary = Color(0xFF06457F);
const Color _darkTextPrimary = Color(0xFFFFFFFF);
const Color _darkTextSecondary = Color(0xFFFFFFFF);
const Color _lightTextPrimary = Color(0xFF06457F);
const Color _lightTextSecondary = Color(0xFF06457F);

class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  final bool? isForceDark;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.isForceDark,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isForceDark ?? (Theme.of(context).brightness == Brightness.dark);
    final textPrimary = isDark ? _darkTextPrimary : _lightTextPrimary;
    final textSecondary = isDark ? _darkTextSecondary : _lightTextSecondary;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Neuro Touch brand accent
        Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, _secondary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Neuro Touch',
              style: GoogleFonts.inter(
                color: _primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        SizedBox(height: screenWidth * 0.04),
        Text(
          title,
          style: GoogleFonts.inter(
            color: textPrimary,
            fontSize: screenWidth * 0.075,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        SizedBox(height: screenWidth * 0.02),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: textSecondary,
            fontSize: screenWidth * 0.038,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
