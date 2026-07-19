import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double blur;
  final double opacity;
  final Color? color;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
    this.borderColor,
    this.blur = 10.0,
    this.opacity = 0.08,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final radius = borderRadius ?? BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? (isDark ? AppColors.glassDark(opacity) : AppColors.glassLight(0.05)),
            borderRadius: radius,
            border: Border.all(
              color: borderColor ?? AppColors.borderColor(isDark),
              width: 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: child,
          ),
        ),
      ),
    );
  }
}
