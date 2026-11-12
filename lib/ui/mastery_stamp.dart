import 'package:flutter/material.dart';

/// KVESMOS' five-point course constellation, drawn from the same coordinates
/// at every size. No new bitmap assets or endless animation.
class MasteryStamp extends StatelessWidget {
  final double size;
  const MasteryStamp({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Созвездие темы открыто',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ConstellationPainter(Theme.of(context).colorScheme),
      ),
    ),
  );
}

class _ConstellationPainter extends CustomPainter {
  final ColorScheme colors;
  _ConstellationPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      scale * .48,
      Paint()..color = colors.primaryContainer,
    );
    final points = [
      const Offset(.25, .61),
      const Offset(.39, .27),
      const Offset(.68, .34),
      const Offset(.76, .67),
      const Offset(.47, .76),
    ].map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
    final line = Paint()
      ..color = colors.primary
      ..strokeWidth = scale * .025
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], line);
    }
    canvas.drawLine(points.first, points.last, line);
    canvas.drawLine(points[1], points.last, line);
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        scale * (i == 1 ? .065 : .045),
        Paint()..color = colors.onPrimaryContainer,
      );
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) => old.colors != colors;
}
