import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class ParkLogoWidget extends StatelessWidget {
  final double size;
  final bool showGlow;
  final Color primaryColor;
  final Color accentColor;

  const ParkLogoWidget({
    super.key,
    this.size = 80.0,
    this.showGlow = true,
    this.primaryColor = AppColors.neonLime,
    this.accentColor = AppColors.deepBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showGlow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.35),
                  blurRadius: size * 0.3,
                  spreadRadius: size * 0.05,
                ),
              ],
            )
          : null,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ParkLogoPainter(
          primaryColor: primaryColor,
          accentColor: accentColor,
        ),
      ),
    );
  }
}

class _ParkLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;

  _ParkLogoPainter({
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final width = size.width;
    final height = size.height;

    // 1. Draw outer glowing pin shield
    final pinPath = Path();
    pinPath.moveTo(center.dx, height * 0.95);
    pinPath.cubicTo(
      width * 0.1, height * 0.6,
      width * 0.05, height * 0.1,
      center.dx, height * 0.1,
    );
    pinPath.cubicTo(
      width * 0.95, height * 0.1,
      width * 0.9, height * 0.6,
      center.dx, height * 0.95,
    );
    pinPath.close();

    // Fill pin background with gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor,
            AppColors.midnightNavy,
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(pinPath, fillPaint);

    // Pin outer stroke/border
    final borderPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.06
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(pinPath, borderPaint);

    // 2. Draw "P" emblem in the center
    final pPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.08
      ..strokeCap = StrokeCap.round;

    final pPath = Path();
    // Vertical stem of P
    pPath.moveTo(width * 0.4, height * 0.28);
    pPath.lineTo(width * 0.4, height * 0.62);

    // Loop of P
    pPath.moveTo(width * 0.4, height * 0.28);
    pPath.cubicTo(
      width * 0.68, height * 0.28,
      width * 0.68, height * 0.45,
      width * 0.4, height * 0.45,
    );

    canvas.drawPath(pPath, pPaint);
  }

  @override
  bool shouldRepaint(covariant _ParkLogoPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor || oldDelegate.accentColor != accentColor;
}
