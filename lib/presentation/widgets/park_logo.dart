import 'package:flutter/material.dart';

class ParkLogoWidget extends StatelessWidget {
  final double size;
  final bool showGlow;
  final Color primaryColor;
  final Color accentColor;

  const ParkLogoWidget({
    super.key,
    this.size = 90.0,
    this.showGlow = true,
    this.primaryColor = const Color(0xFF00F0FF), // Electric Neon Blue
    this.accentColor = const Color(0xFF00E676),  // Emerald Green
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showGlow
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.225),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: size * 0.25,
                  spreadRadius: size * 0.02,
                  offset: Offset(0, size * 0.08),
                ),
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.15),
                  blurRadius: size * 0.35,
                  spreadRadius: size * 0.01,
                  offset: Offset(0, size * 0.12),
                ),
              ],
            )
          : null,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ParkLogoPainter(
          neonBlue: primaryColor,
          emeraldGreen: accentColor,
        ),
      ),
    );
  }
}

class _ParkLogoPainter extends CustomPainter {
  final Color neonBlue;
  final Color emeraldGreen;

  _ParkLogoPainter({
    required this.neonBlue,
    required this.emeraldGreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cornerRadius = w * 0.225; // iOS 18 / Material 3 Squircle Corner Radius

    // 1. Dark Slate Gray Outer Frame (App Icon Container)
    final bgRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(cornerRadius),
    );

    // Dark Slate Gray Gradient (#1E293B -> #0F172A -> #090D16)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1E293B), // Dark Slate Light
          Color(0xFF0F172A), // Dark Slate Base
          Color(0xFF090D16), // Dark Slate Deep
        ],
      ).createShader(bgRRect.outerRect);

    canvas.drawRRect(bgRRect, bgPaint);

    // Subtle Rim Stroke Highlight
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          neonBlue.withValues(alpha: 0.45),
          emeraldGreen.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.05),
        ],
      ).createShader(bgRRect.outerRect);

    canvas.drawRRect(bgRRect, rimPaint);

    // 2. Glossy Top Highlight Reflection
    final glossPath = Path();
    glossPath.moveTo(0, cornerRadius);
    glossPath.quadraticBezierTo(w * 0.5, h * 0.12, w, cornerRadius);
    glossPath.lineTo(w, 0);
    glossPath.lineTo(0, 0);
    glossPath.close();

    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.22));

    canvas.drawPath(glossPath, glossPaint);

    // 3. Central Icon Symbol: Location Pin + Capital "P" + Car / Slot Emblem
    final cx = w * 0.5;

    // Pin Dimensions
    final pinW = w * 0.54;
    final pinH = h * 0.65;
    final pinTop = h * 0.16;

    final pinPath = Path();

    // Location Pin Head + Pointed Tail
    pinPath.moveTo(cx - pinW * 0.48, pinTop + pinH * 0.35);
    // Top Arc of Pin
    pinPath.cubicTo(
      cx - pinW * 0.48, pinTop - pinH * 0.04,
      cx + pinW * 0.48, pinTop - pinH * 0.04,
      cx + pinW * 0.48, pinTop + pinH * 0.35,
    );
    // Right curve down to pin tip
    pinPath.cubicTo(
      cx + pinW * 0.48, pinTop + pinH * 0.58,
      cx + pinW * 0.20, pinTop + pinH * 0.85,
      cx, pinTop + pinH,
    );
    // Left curve up to pin head
    pinPath.cubicTo(
      cx - pinW * 0.20, pinTop + pinH * 0.85,
      cx - pinW * 0.48, pinTop + pinH * 0.58,
      cx - pinW * 0.48, pinTop + pinH * 0.35,
    );
    pinPath.close();

    // 3D Ambient Glow / Shadow under the Pin
    canvas.drawPath(
      pinPath.shift(Offset(0, h * 0.03)),
      Paint()
        ..color = neonBlue.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );

    // Electric Neon Blue to Emerald Green 3D Gradient Fill
    final pinFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          neonBlue,                // Electric Neon Blue (#00F0FF)
          const Color(0xFF00B0FF), // Vivid Cyan Blue
          emeraldGreen,            // Emerald Green (#00E676)
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(pinPath, pinFillPaint);

    // 4. Inner Cutout forming the Capital Letter "P" Loop
    final loopR = pinW * 0.22;
    final loopCx = cx + pinW * 0.03;
    final loopCy = pinTop + pinH * 0.31;

    final innerPath = Path();
    innerPath.addOval(Rect.fromCircle(center: Offset(loopCx, loopCy), radius: loopR));

    final innerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0F172A),
          Color(0xFF1E293B),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(innerPath, innerPaint);

    // 5. Minimalist Car / Parking Slot Symbol inside the "P" Loop
    final carPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          neonBlue,
          emeraldGreen,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.028
      ..strokeCap = StrokeCap.round;

    final carPath = Path();
    // Sleek minimalist car roof arc
    carPath.moveTo(loopCx - loopR * 0.5, loopCy + loopR * 0.15);
    carPath.quadraticBezierTo(loopCx, loopCy - loopR * 0.55, loopCx + loopR * 0.5, loopCy + loopR * 0.15);
    // Parking slot side brackets
    carPath.moveTo(loopCx - loopR * 0.55, loopCy + loopR * 0.15);
    carPath.lineTo(loopCx + loopR * 0.55, loopCy + loopR * 0.15);

    canvas.drawPath(carPath, carPaint);

    // Wheel Accents
    final wheelPaint = Paint()
      ..color = emeraldGreen
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(loopCx - loopR * 0.28, loopCy + loopR * 0.32), w * 0.015, wheelPaint);
    canvas.drawCircle(Offset(loopCx + loopR * 0.28, loopCy + loopR * 0.32), w * 0.015, wheelPaint);
  }

  @override
  bool shouldRepaint(covariant _ParkLogoPainter oldDelegate) =>
      oldDelegate.neonBlue != neonBlue || oldDelegate.emeraldGreen != emeraldGreen;
}
