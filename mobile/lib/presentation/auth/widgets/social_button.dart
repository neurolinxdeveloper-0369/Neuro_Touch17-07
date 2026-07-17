import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


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
    const bgColor = Color(0xFF06457F);
    const borderColor = Color(0xFF06457F);
    const textColor = Colors.white;

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
