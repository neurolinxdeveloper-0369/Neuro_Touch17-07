import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _cardDark = Color(0xFF45484D);
const Color _borderDark = Color(0xFF55595E);
const Color _darkTextPrimary = Color(0xFFFFFFFF);
const Color _borderLight = Color(0xFFD1D5DB);
const Color _lightTextPrimary = Color(0xFF0F172A);

class SocialButton extends StatelessWidget {
  final String label;
  final String? assetPath;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isDark;

  const SocialButton({
    super.key,
    required this.label,
    this.assetPath,
    this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? _cardDark : Colors.white;
    final borderColor = isDark ? _borderDark : _borderLight;
    final textColor = isDark ? _darkTextPrimary : _lightTextPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.7),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (assetPath != null) ...[
              Image.asset(assetPath!, width: 20, height: 20,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.g_mobiledata_rounded,
                    color: textColor,
                    size: 22,
                  )),
            ] else if (icon != null) ...[
              Icon(icon, color: textColor, size: 22),
            ],
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
