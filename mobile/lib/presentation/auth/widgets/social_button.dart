import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';
import '../../common/widgets/glass_panel.dart';

class SocialButton extends StatelessWidget {
  final String label;
  final String? assetPath;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isLoading;

  const SocialButton({
    super.key,
    required this.label,
    this.assetPath,
    this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(vertical: 14),
        borderRadius: BorderRadius.circular(16),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (assetPath != null) ...[
                    Image.asset(
                      assetPath!,
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.account_circle_outlined,
                        color: AppColors.textPrimary(isDark),
                        size: 22,
                      ),
                    ),
                  ] else if (icon != null) ...[
                    Icon(
                      icon,
                      color: AppColors.textPrimary(isDark),
                      size: 22,
                    ),
                  ],
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
