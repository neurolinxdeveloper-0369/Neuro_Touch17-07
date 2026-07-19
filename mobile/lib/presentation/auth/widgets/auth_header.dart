import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showBrandAccent;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBrandAccent = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBrandAccent) ...[
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'NEURO TOUCH',
                style: AppTypography.label.copyWith(
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Text(
          title,
          style: AppTypography.h1,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }
}
