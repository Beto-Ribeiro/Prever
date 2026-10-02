import 'package:flutter/material.dart';

class AbstractBackgroundPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color tertiaryColor;

  AbstractBackgroundPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.tertiaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / 390;
    final double scaleY = size.height / 844;

    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        94.3,
      );

    void drawEllipse(
      double cx,
      double cy,
      double rx,
      double ry,
      Color color,
    ) {
      paint.color = color;

      canvas.drawOval(
        Rect.fromLTWH(
          (cx - rx) * scaleX,
          (cy - ry) * scaleY,
          (rx * 2) * scaleX,
          (ry * 2) * scaleY,
        ),
        paint,
      );
    }

    drawEllipse(34.5, 73.5, 83.5, 78.5, primaryColor);
    drawEllipse(315.5, 52.5, 142.5, 153.5, secondaryColor);
    drawEllipse(199.5, 235.5, 119.5, 120.5, tertiaryColor);
    drawEllipse(258.5, 406.0, 115.5, 104.0, primaryColor);
    drawEllipse(24.0, 272.5, 108.0, 106.5, secondaryColor);
    drawEllipse(118.0, 600.0, 96.0, 86.0, primaryColor);
    drawEllipse(196.5, 507.5, 94.5, 93.0, tertiaryColor);
    drawEllipse(291.5, 663.0, 109.0, 114.5, secondaryColor);
    drawEllipse(101.5, 693.0, 112.0, 100.5, tertiaryColor);
    drawEllipse(355.5, 820.5, 125.5, 123.5, secondaryColor);
    drawEllipse(145.5, 166.5, 80.5, 79.5, tertiaryColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}