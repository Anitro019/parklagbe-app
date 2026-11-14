import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

enum ParkButtonType { primary, secondary, text }

class ParkButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ParkButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const ParkButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = ParkButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget childContent;
    if (isLoading) {
      childContent = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            type == ParkButtonType.primary
                ? (isDark ? AppColors.midnightNavy : Colors.white)
                : AppColors.neonLime,
          ),
        ),
      );
    } else {
      childContent = FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    Widget buttonWidget;
    switch (type) {
      case ParkButtonType.primary:
        buttonWidget = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? AppColors.neonLime : AppColors.accentLight,
            foregroundColor: isDark ? AppColors.midnightNavy : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: childContent,
        );
        break;
      case ParkButtonType.secondary:
        buttonWidget = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? AppColors.neonLime : AppColors.accentLight,
            side: BorderSide(
              color: isDark ? AppColors.neonLime : AppColors.accentLight,
              width: 1.5,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: childContent,
        );
        break;
      case ParkButtonType.text:
        buttonWidget = TextButton(
          onPressed: isLoading ? null : onPressed,
          child: childContent,
        );
        break;
    }

    if (width != null) {
      return SizedBox(width: width, child: buttonWidget);
    }
    return SizedBox(width: double.infinity, child: buttonWidget);
  }
}
