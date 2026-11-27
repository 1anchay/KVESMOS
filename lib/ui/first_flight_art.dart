import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../domain/first_flight.dart';
import 'flight_ui.dart';

const flightInk = Color(0xff101c31);
const flightPanel = Color(0xff192b43);
const flightMint = Color(0xff9ce8cd);
const flightAmber = Color(0xffffcc8e);
const flightText = Color(0xffeef2ec);

/// The cutaway shares the same normalized coordinates as interactive objects.
class FlightDeckPainter extends CustomPainter {
  final FlightRoom room;
  final bool powered, wired, charged, navigable;
  final int a, b;
  FlightDeckPainter(FirstFlight f)
    : room = f.room,
      powered = f.powered,
      wired = f.wired,
      charged = f.charged,
      navigable = f.navigable,
      a = f.rotorA,
      b = f.rotorB;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Offset p(double x, double y) => Offset(w * x, h * y);
    Rect box(double l, double t, double r, double b) =>
        Rect.fromPoints(p(l, t), p(r, b));
    final brush = Paint();
    final sky = Offset.zero & size;
    canvas.drawRect(
      sky,
      brush
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [Color(0xff061222), Color(0xff193145)],
        ).createShader(sky),
    );
    brush.shader = null;
    final stars = math.Random(room.index + 7);
    for (var i = 0; i < 86; i++) {
      final x = stars.nextDouble(), y = stars.nextDouble();
      canvas.drawCircle(
        p(x, y),
        i % 9 == 0 ? 1.4 : .65,
        brush
          ..color = const Color(
            0xffdcecf2,
          ).withValues(alpha: .12 + (i % 5) * .14),
      );
    }
    if (room == FlightRoom.bridge) {
      canvas.drawOval(
        box(.08, -.28, .92, .33),
        brush..color = const Color(0xff294e60),
      );
      canvas.drawOval(
        box(.14, -.30, .96, .25),
        brush..color = const Color(0xff417382),
      );
      canvas.drawArc(
        box(.08, -.28, .92, .33),
        .1,
        2.8,
        false,
        Paint()
          ..color = flightMint.withValues(alpha: .6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    Path hull(double dy) => Path()
      ..moveTo(w * .066, h * .32 + dy)
      ..lineTo(w * .211, h * .169 + dy)
      ..lineTo(w * .789, h * .169 + dy)
      ..lineTo(w * .934, h * .32 + dy)
      ..lineTo(w * .934, h * .776 + dy)
      ..lineTo(w * .766, h * .919 + dy)
      ..lineTo(w * .234, h * .919 + dy)
      ..lineTo(w * .066, h * .776 + dy)
      ..close();
    final floor = hull(0);
    canvas.drawShadow(hull(13), const Color(0xff040916), 14, false);
    canvas.drawPath(hull(12), brush..color = const Color(0xff142740));
    canvas.drawPath(
      floor,
      brush
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: powered
              ? const [Color(0xff466a71), Color(0xff233e51)]
              : const [Color(0xff365163), Color(0xff1d3048)],
        ).createShader(sky),
    );
    brush.shader = null;
    canvas.save();
    canvas.clipPath(floor);
    final noise = math.Random(63);
    for (var i = 0; i < 1000; i++) {
      final at = p(noise.nextDouble(), noise.nextDouble());
      canvas.drawCircle(
        at,
        noise.nextDouble() * 1.1,
        brush
          ..color = const Color(
            0xffd1e5e0,
          ).withValues(alpha: i.isEven ? .10 : .05),
      );
    }
    final seam = Paint()
      ..color = const Color(0xff13293c)
      ..strokeWidth = 1.3;
    for (var i = 2; i <= 9; i++) {
      final y = i / 10;
      canvas.drawLine(p(0, y), p(1, y), seam);
      for (var j = 1; j < 10; j++) {
        if ((j + i).isOdd) {
          canvas.drawLine(p(j / 10, y), p(j / 10, y + .10), seam);
        }
      }
    }
    final lane = RRect.fromRectAndRadius(
      box(.41, .22, .59, .90),
      const Radius.circular(11),
    );
    canvas.drawRRect(
      lane,
      brush..color = const Color(0xffa6cccb).withValues(alpha: .12),
    );
    for (final x in [.43, .57]) {
      for (var i = 0; i < 12; i++) {
        canvas.drawLine(
          p(x, .25 + i * .053),
          p(x, .27 + i * .053),
          Paint()
            ..color = flightAmber.withValues(alpha: .55)
            ..strokeWidth = 2,
        );
      }
    }
    for (final x in [.09, .88]) {
      for (var i = 0; i < 9; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            box(x, .36 + i * .043, x + .026, .374 + i * .043),
            const Radius.circular(2),
          ),
          brush
            ..color = (powered ? flightMint : flightAmber).withValues(
              alpha: i.isEven ? .82 : .24,
            ),
        );
      }
    }
    void cabinet(double l, double t, double r, double b, Color top) {
      final geometry = box(l, t, r, b);
      final panel = RRect.fromRectAndRadius(geometry, const Radius.circular(8));
      canvas.drawRRect(
        panel.shift(const Offset(0, 6)),
        brush..color = flightInk,
      );
      canvas.drawRRect(panel, brush..color = top);
      canvas.drawRRect(
        panel,
        Paint()
          ..color = const Color(0xff7a9a9d)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      canvas.drawLine(
        geometry.bottomLeft + const Offset(6, -4),
        geometry.bottomRight + const Offset(-6, -4),
        Paint()
          ..color = flightInk
          ..strokeWidth = 1.5,
      );
    }

    const metal = Color(0xff4c6975);
    switch (room) {
      case FlightRoom.airlock:
        cabinet(.33, .14, .67, .34, metal);
        cabinet(.405, .16, .595, .31, flightInk);
        cabinet(.105, .57, .29, .74, const Color(0xff876b56));
        cabinet(.69, .29, .86, .50, const Color(0xff284b66));
        break;
      case FlightRoom.workshop:
        cabinet(.12, .18, .34, .38, metal);
        cabinet(.69, .20, .87, .37, metal);
        cabinet(.65, .40, .84, .54, const Color(0xff696157));
        cabinet(.74, .68, .88, .82, const Color(0xff696157));
        break;
      case FlightRoom.bridge:
        cabinet(.25, .18, .76, .34, const Color(0xff38596c));
        for (var i = 0; i < 9; i++) {
          canvas.drawCircle(
            p(.31 + i * .047, .31),
            2,
            brush..color = navigable || i.isEven ? flightMint : flightAmber,
          );
        }
        cabinet(.68, .34, .87, .49, const Color(0xff756659));
        cabinet(.61, .58, .82, .74, metal);
        cabinet(.12, .55, .32, .71, metal);
        break;
    }
    if (room == FlightRoom.workshop) {
      void trace(List<Offset> points, bool active) {
        final wire = Path()..addPolygon(points, false);
        canvas.drawPath(
          wire,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 9
            ..color = flightInk,
        );
        canvas.drawPath(
          wire,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = active ? 4 : 2
            ..color = active ? flightMint : const Color(0xff789597),
        );
      }

      trace([p(.23, .37), p(.23, .65), p(.35, .65)], charged && wired);
      trace([p(.35, .65), p(.66, .65)], charged && wired && a == 0);
      trace([
        p(.66, .65),
        p(.66, .35),
        p(.79, .35),
      ], charged && wired && a == 0 && b == 3);
    }
    if (room == FlightRoom.bridge && navigable) {
      final pool = box(.14, .2, .86, .78);
      canvas.drawOval(
        pool,
        brush
          ..shader = RadialGradient(
            colors: [flightMint.withValues(alpha: .46), Colors.transparent],
          ).createShader(pool),
      );
      brush.shader = null;
    }
    canvas.restore();
    canvas.drawPath(
      floor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xff698f9a),
    );
    for (final x in [.24, .76]) {
      for (final y in [.19, .89]) {
        canvas.drawCircle(p(x, y), 2.2, brush..color = const Color(0xffc9dfd5));
      }
    }
  }

  @override
  bool shouldRepaint(FlightDeckPainter old) =>
      room != old.room ||
      powered != old.powered ||
      wired != old.wired ||
      charged != old.charged ||
      navigable != old.navigable ||
      a != old.a ||
      b != old.b;
}

/// Equipment pictograms identify the same world objects, inventory and words.
class FlightProp extends StatelessWidget {
  const FlightProp(
    this.icon, {
    super.key,
    this.color = flightMint,
    this.size = 46,
    this.turn = 0,
    this.themed = false,
  });
  final IconData icon;
  final Color color;
  final double size;
  final int turn;
  final bool themed;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: themed ? FlightPalette.of(context).inset : null,
      gradient: themed
          ? null
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff385867), flightInk],
            ),
      borderRadius: BorderRadius.circular(size * .24),
      border: Border.all(color: color.withValues(alpha: .72)),
      boxShadow: themed
          ? const []
          : const [
              BoxShadow(
                color: Color(0xdd0b1829),
                offset: Offset(0, 3),
                blurRadius: 3,
              ),
            ],
    ),
    child: Center(
      child: RotatedBox(
        quarterTurns: turn,
        child: Icon(icon, color: color, size: size * .56),
      ),
    ),
  );
}

class FlightPilotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 52, size.height / 62);
    final paint = Paint();
    RRect rect(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));
    canvas.drawOval(
      const Rect.fromLTWH(6, 52, 41, 10),
      paint..color = const Color(0x99101c31),
    );
    canvas.drawRRect(
      rect(4, 30, 44, 21, 8),
      paint..color = const Color(0xffb56849),
    );
    canvas.drawRRect(rect(13, 43, 9, 15, 3), paint..color = flightInk);
    canvas.drawRRect(rect(29, 43, 9, 15, 3), paint);
    canvas.drawRRect(rect(10, 26, 32, 26, 10), paint..color = flightAmber);
    canvas.drawRRect(rect(12, 7, 28, 29, 12), paint..color = flightText);
    canvas.drawRRect(
      rect(15, 14, 22, 15, 7),
      paint..color = const Color(0xff173b52),
    );
    canvas.drawLine(
      const Offset(20, 18),
      const Offset(28, 18),
      paint
        ..color = flightMint
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(27, 42),
      3,
      paint..color = const Color(0xffb56849),
    );
  }

  @override
  bool shouldRepaint(FlightPilotPainter oldDelegate) => false;
}
