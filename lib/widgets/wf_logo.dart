import 'package:flutter/material.dart';

/// Logo Wifensor : le guerrier au bouclier Wi-Fi (même dessin que assets/logo.svg).
class WfLogo extends StatelessWidget {
  final double size;
  const WfLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    Paint fill(int c) => Paint()..color = Color(c);

    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(22)),
        fill(0xFF1565C0));
    canvas.drawLine(
        const Offset(20, 88),
        const Offset(78, 18),
        Paint()
          ..color = const Color(0xFFFFD27A)
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        Path()
          ..moveTo(78, 18)
          ..lineTo(84, 8)
          ..lineTo(72, 14)
          ..close(),
        fill(0xFFFFD27A));
    canvas.drawPath(
        Path()
          ..moveTo(36, 42)
          ..quadraticBezierTo(36, 19, 50, 17)
          ..quadraticBezierTo(64, 19, 64, 42)
          ..close(),
        fill(0xFFE8EEF8));
    canvas.drawPath(
        Path()
          ..moveTo(42, 30)
          ..lineTo(58, 30)
          ..lineTo(58, 34)
          ..lineTo(52, 34)
          ..lineTo(52, 40)
          ..lineTo(48, 40)
          ..lineTo(48, 34)
          ..lineTo(42, 34)
          ..close(),
        fill(0xFF0D1B2E));
    canvas.drawPath(
        Path()
          ..moveTo(37, 21)
          ..quadraticBezierTo(48, 3, 67, 13)
          ..quadraticBezierTo(57, 11, 50, 17)
          ..quadraticBezierTo(43, 14, 37, 21)
          ..close(),
        fill(0xFFD7262D));
    canvas.drawPath(
        Path()
          ..moveTo(50, 40)
          ..lineTo(75, 48)
          ..lineTo(75, 63)
          ..cubicTo(75, 77, 64, 86, 50, 91)
          ..cubicTo(36, 86, 25, 77, 25, 63)
          ..lineTo(25, 48)
          ..close(),
        fill(0xFFFFFFFF));
    final wave = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(37, 63)
          ..arcToPoint(const Offset(63, 63), radius: const Radius.circular(18)),
        wave);
    canvas.drawPath(
        Path()
          ..moveTo(42, 69)
          ..arcToPoint(const Offset(58, 69), radius: const Radius.circular(10)),
        wave);
    canvas.drawCircle(const Offset(50, 75), 4, fill(0xFF1565C0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
