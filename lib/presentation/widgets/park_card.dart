import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class ParkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool showGlowBorder;

  const ParkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.backgroundColor,
    this.showGlowBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? AppColors.deepBlue : AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showGlowBorder
              ? AppColors.neonLime
              : (isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight),
          width: showGlowBorder ? 1.5 : 1,
        ),
        boxShadow: showGlowBorder
            ? [
                BoxShadow(
                  color: AppColors.neonLime.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }

    return content;
  }
}
