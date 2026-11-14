import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Render ParkLagbee 1024x1024 App Icon PNG', () async {
    const double size = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    final w = size;
    final h = size;
    final cornerRadius = w * 0.225;

    // 1. Dark Slate Gray Outer Frame (App Icon Container)
    final bgRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(cornerRadius),
    );

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1E293B),
          Color(0xFF0F172A),
          Color(0xFF090D16),
        ],
      ).createShader(bgRRect.outerRect);

    canvas.drawRRect(bgRRect, bgPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x7300F0FF),
          Color(0x4000E676),
          Color(0x0DFFFFFF),
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
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x24FFFFFF),
          Color(0x00FFFFFF),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.22));

    canvas.drawPath(glossPath, glossPaint);

    // 3. Central Icon Symbol
    final cx = w * 0.5;
    final pinW = w * 0.54;
    final pinH = h * 0.65;
    final pinTop = h * 0.16;

    final pinPath = Path();

    pinPath.moveTo(cx - pinW * 0.48, pinTop + pinH * 0.35);
    pinPath.cubicTo(
      cx - pinW * 0.48, pinTop - pinH * 0.04,
      cx + pinW * 0.48, pinTop - pinH * 0.04,
      cx + pinW * 0.48, pinTop + pinH * 0.35,
    );
    pinPath.cubicTo(
      cx + pinW * 0.48, pinTop + pinH * 0.58,
      cx + pinW * 0.20, pinTop + pinH * 0.85,
      cx, pinTop + pinH,
    );
    pinPath.cubicTo(
      cx - pinW * 0.20, pinTop + pinH * 0.85,
      cx - pinW * 0.48, pinTop + pinH * 0.58,
      cx - pinW * 0.48, pinTop + pinH * 0.35,
    );
    pinPath.close();

    final pinFillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF00F0FF),
          Color(0xFF00B0FF),
          Color(0xFF00E676),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(pinPath, pinFillPaint);

    // 4. Inner Cutout forming "P" Loop
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

    // 5. Minimalist Car Accent
    final carPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFF00F0FF),
          Color(0xFF00E676),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.028
      ..strokeCap = StrokeCap.round;

    final carPath = Path();
    carPath.moveTo(loopCx - loopR * 0.5, loopCy + loopR * 0.15);
    carPath.quadraticBezierTo(loopCx, loopCy - loopR * 0.55, loopCx + loopR * 0.5, loopCy + loopR * 0.15);
    carPath.moveTo(loopCx - loopR * 0.55, loopCy + loopR * 0.15);
    carPath.lineTo(loopCx + loopR * 0.55, loopCy + loopR * 0.15);

    canvas.drawPath(carPath, carPaint);

    final wheelPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(loopCx - loopR * 0.28, loopCy + loopR * 0.32), w * 0.015, wheelPaint);
    canvas.drawCircle(Offset(loopCx + loopR * 0.28, loopCy + loopR * 0.32), w * 0.015, wheelPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(1024, 1024);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final file = File('assets/icon/app_icon.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(1000));
  });
}
