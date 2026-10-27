import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design.dart';

/// Original Flutter geometry, no new bitmap assets or generation service.
class JourneyPlanetPainter extends CustomPainter {
  final int index;
  final Color color;
  const JourneyPlanetPainter(this.index, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final p = Paint();
    for (final point in [
      const Offset(12, 15),
      const Offset(87, 21),
      const Offset(84, 84),
    ]) {
      canvas.drawLine(
        point - const Offset(3, 0),
        point + const Offset(3, 0),
        p
          ..color = starYellow
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        point - const Offset(0, 3),
        point + const Offset(0, 3),
        p,
      );
    }
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(index.isEven ? -.3 : .3);
    final ring = Rect.fromCenter(center: Offset.zero, width: 94, height: 31);
    if (index % 3 != 1) {
      canvas.drawOval(
        ring,
        p
          ..color = color.withValues(alpha: .6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
    }
    p.style = PaintingStyle.fill;
    final sphere = Path()..addOval(const Rect.fromLTWH(-31, -31, 62, 62));
    canvas.drawPath(
      sphere,
      p
        ..shader = RadialGradient(
          center: const Alignment(-.6, -.7),
          colors: [
            Color.lerp(color, Colors.white, .65)!,
            color,
            Color.lerp(color, space, .4)!,
          ],
        ).createShader(const Rect.fromLTWH(-31, -31, 62, 62)),
    );
    p.shader = null;
    canvas.save();
    canvas.clipPath(sphere);
    if (index % 3 == 1) {
      for (final o in [
        const Offset(-17, -15),
        const Offset(8, -3),
        const Offset(16, 19),
      ]) {
        canvas.drawCircle(o, 12, p..color = mintGlow.withValues(alpha: .6));
      }
    } else {
      for (var i = 0; i < 3; i++) {
        canvas.drawArc(
          Rect.fromLTWH(-42, -23 + i * 15, 84, 24),
          0,
          math.pi,
          false,
          p
            ..color = Colors.white.withValues(alpha: .25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
      }
    }
    p.style = PaintingStyle.fill;
    canvas.drawCircle(
      const Offset(-15, -16),
      7,
      p..color = Colors.white.withValues(alpha: .25),
    );
    canvas.restore();
    canvas.drawPath(
      sphere,
      p
        ..color = space.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (index % 3 != 1) {
      canvas.drawArc(
        ring,
        0,
        math.pi,
        false,
        p
          ..color = Color.lerp(color, Colors.white, .55)!
          ..strokeWidth = 5,
      );
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(JourneyPlanetPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.color != color;
}
