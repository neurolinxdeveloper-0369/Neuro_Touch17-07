import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final int? maxLength;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.maxLength,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          maxLength: maxLength,
          enabled: enabled,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          onChanged: onChanged,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textPrimary(isDark),
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            prefixIcon: prefixIcon != null 
                ? Icon(prefixIcon, size: 20, color: AppColors.textSecondary(isDark)) 
                : null,
            suffixIcon: suffixIcon,
            fillColor: isDark ? AppColors.glassDark(0.06) : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.borderColor(isDark)),
            ),
          ),
        ),
      ],
    );
  }
}
