import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';

class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = AppColors.surface;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    final gridPaint = Paint()
      ..color = AppColors.panelBorder.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    // Draw simple grid points (dots)
    for (double x = 0; x < size.width; x += 30) {
      for (double y = 0; y < size.height; y += 30) {
        canvas.drawCircle(Offset(x, y), 0.5, gridPaint);
      }
    }

    final wavePaint1 = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final wavePaint2 = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final squarePaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path1 = Path();
    final path2 = Path();
    final pathSquare = Path();

    // Generate fake waveform
    for (double x = 0; x < size.width; x++) {
      double t = x / size.width;
      
      // sine waves
      double y1 = size.height / 2 + math.sin(t * math.pi * 4) * (size.height / 3.5);
      double y2 = size.height / 2 + math.sin(t * math.pi * 4 - 0.5) * (size.height / 4.5);
      
      // square wave
      double squareVal = (math.sin(t * math.pi * 6) > 0) ? (size.height / 2 - 40) : (size.height / 2 + 40);

      if (x == 0) {
        path1.moveTo(x, y1);
        path2.moveTo(x, y2);
        pathSquare.moveTo(x, squareVal);
      } else {
        path1.lineTo(x, y1);
        path2.lineTo(x, y2);
        pathSquare.lineTo(x, squareVal);
      }
    }

    canvas.drawPath(pathSquare, squarePaint);
    canvas.drawPath(path1, wavePaint1);
    canvas.drawPath(path2, wavePaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
