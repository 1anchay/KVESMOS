import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/fishing.dart';

const nereyaArt = 'assets/kvesmos/fishing/nereya.webp';

class FishPortrait extends StatelessWidget {
  const FishPortrait(
    this.fish, {
    super.key,
    this.hidden = false,
    this.size = 112,
  });
  final SpaceFish fish;
  final bool hidden;
  final double size;

  @override
  Widget build(BuildContext context) {
    final picture = Image.asset(
      'assets/kvesmos/fishing/${fish.name}.webp',
      width: size,
      height: size * .84,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
    return hidden
        ? ColorFiltered(
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.onSurface.withValues(alpha: .64),
              BlendMode.srcIn,
            ),
            child: picture,
          )
        : picture;
  }
}

class FishingWater extends StatelessWidget {
  const FishingWater({super.key, required this.game, required this.select});
  final FishingGame game;
  final void Function(double) select;

  @override
  Widget build(BuildContext context) {
    final quiet = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final aiming =
              game.phase == FishingPhase.aiming ||
              game.phase == FishingPhase.charging;
          return GestureDetector(
            key: const Key('fishing-water'),
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapUp: aiming
                ? (t) => select(t.localPosition.dx / bounds.maxWidth)
                : null,
            onHorizontalDragUpdate: aiming
                ? (t) => select(t.localPosition.dx / bounds.maxWidth)
                : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  nereyaArt,
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
                if (game.hookedFish case final fish?)
                  Positioned(
                    left:
                        ((game.bearing + game.drift) *
                                    (1 - game.progress * .88) +
                                .65 * game.progress * .88) *
                            bounds.maxWidth -
                        29,
                    top:
                        ((.81 - game.depth * .43) * (1 - game.progress * .88) +
                                .88 * game.progress * .88) *
                            bounds.maxHeight -
                        10,
                    child: Opacity(
                      opacity: .42,
                      child: Transform.flip(
                        flipX: game.drift > 0,
                        child: FishPortrait(fish, hidden: true, size: 58),
                      ),
                    ),
                  ),
                CustomPaint(painter: _WaterPainter(game, quiet)),
                if (aiming)
                  Positioned(
                    left: 6,
                    right: 6,
                    top: 9,
                    child: Row(
                      children: [
                        for (final zone in FishingZone.values)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: _ZoneLabel(
                                zone: zone,
                                selected: game.zone == zone,
                                onTap: () => select((zone.index + .5) / 3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (game.phase == FishingPhase.bite)
                  const Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(child: _WaterLabel('Поклёвка!')),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ZoneLabel extends StatelessWidget {
  const _ZoneLabel({
    required this.zone,
    required this.selected,
    required this.onTap,
  });
  final FishingZone zone;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? const Color(0xffe2f6e5) : const Color(0xe32a3b51),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        key: Key('fishing-zone-${zone.name}'),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: Text(
            zone.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.08,
              fontWeight: FontWeight.w800,
              color: selected ? const Color(0xff173f38) : Colors.white,
            ),
          ),
        ),
      ),
    ),
  );
}

class _WaterLabel extends StatelessWidget {
  const _WaterLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      color: const Color(0xfffff3ca),
      boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38)],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xff533515),
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _WaterPainter extends CustomPainter {
  _WaterPainter(FishingGame game, this.reduced)
    : bearing = game.bearing,
      depth = game.depth,
      moment = game.elapsed,
      phase = game.phase,
      time = game.waterTime,
      progress = game.progress,
      drift = game.drift,
      tension = game.tension,
      travel = game.travel,
      hasLure = game.hasLure,
      dangerous = game.dangerous;

  final FishingPhase phase;
  final double time, bearing, depth, moment, progress, drift, tension, travel;
  final bool reduced, hasLure, dangerous;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(double x, double y) => Offset(size.width * x, size.height * y);
    final t = reduced ? 0.0 : time;
    final stroke = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 23; i++) {
      final x = ((i * .157 + t * .016) % .95) + .02;
      final y = .33 + (i * .071 % .49);
      final length = .012 + .046 * y + .008 * math.cos(t * 1.5 + i);
      stroke
        ..color = const Color(
          0xffc1fbef,
        ).withValues(alpha: .055 + .07 * (1 + math.sin(t * 2 + i)) / 2)
        ..strokeWidth = 1 + y;
      canvas.drawLine(at(x, y), at(x + length, y), stroke);
    }

    for (var i = 0; i < 3; i++) {
      final x = .15 + i * .31 + math.sin(t * (.55 + i * .12) + i) * .07;
      final y = .64 - i * .062 + math.sin(t * .72 + i) * .026;
      final tail = math.sin(t * 5 + i) * 2.4;
      final p = at(x, y);
      final shadow = Path()
        ..moveTo(p.dx - 9, p.dy)
        ..quadraticBezierTo(p.dx - 2, p.dy - 6, p.dx + 8, p.dy - 1)
        ..lineTo(p.dx + 15, p.dy - 4 + tail)
        ..lineTo(p.dx + 14, p.dy + 4 + tail)
        ..lineTo(p.dx + 7, p.dy + 1)
        ..quadraticBezierTo(p.dx - 2, p.dy + 5, p.dx - 9, p.dy)
        ..close();
      canvas.drawPath(shadow, Paint()..color = const Color(0x68223a58));
    }

    final ready =
        phase == FishingPhase.aiming || phase == FishingPhase.charging;
    final grip = at(.92, 1.03);
    final bow = phase == FishingPhase.fighting ? .11 * tension : .0;
    final tip = at(.72 + (bearing - .5) * .2, .57 + bow);
    final rod = Path()
      ..moveTo(grip.dx, grip.dy)
      ..quadraticBezierTo(
        size.width * .79,
        size.height * (.73 + bow),
        tip.dx,
        tip.dy,
      );
    canvas.drawPath(
      rod,
      stroke
        ..color = const Color(0xff211d30)
        ..strokeWidth = 7,
    );
    canvas.drawPath(
      rod,
      stroke
        ..color = const Color(0xffdfb985)
        ..strokeWidth = 3.5,
    );
    canvas.drawPath(
      rod,
      stroke
        ..color = const Color(0xfffde1a5)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      at(.865, .94),
      9,
      Paint()..color = const Color(0xff27384d),
    );
    canvas.drawCircle(
      at(.865, .94),
      5.5,
      stroke
        ..color = const Color(0xffa2c3c8)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      at(.893, .96),
      grip,
      stroke
        ..color = const Color(0xff594453)
        ..strokeWidth = 10,
    );

    if (ready) {
      final target = at(bearing, .60);
      final aim = Paint()
        ..color = const Color(0xffdcffe7)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(target, 13, aim);
      canvas.drawLine(
        target - const Offset(19, 0),
        target - const Offset(7, 0),
        aim,
      );
      canvas.drawLine(
        target + const Offset(7, 0),
        target + const Offset(19, 0),
        aim,
      );
      canvas.drawLine(
        target - const Offset(0, 19),
        target - const Offset(0, 7),
        aim,
      );
      canvas.drawLine(
        target + const Offset(0, 7),
        target + const Offset(0, 19),
        aim,
      );
    }
    if (!hasLure) return;

    final cast = at(bearing, .81 - depth * .43);
    final biting = phase == FishingPhase.bite;
    final fighting = phase == FishingPhase.fighting;
    final moving = math.sin(t * (biting ? 16 : 4));
    var bobber =
        cast +
        Offset(drift * size.width, (reduced ? 0 : moving * (biting ? 8 : 1.3)));
    if (phase == FishingPhase.flight) {
      bobber =
          Offset.lerp(tip, cast, travel)! -
          Offset(
            0,
            (reduced ? 0 : math.sin(travel * math.pi)) * size.height * .20,
          );
    } else if (fighting) {
      bobber = Offset.lerp(bobber, at(.65, .88), progress * .88)!;
    }
    final line = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
        (tip.dx + bobber.dx) / 2,
        (tip.dy + bobber.dy) / 2 + (fighting ? (1 - tension) * 34 : 16),
        bobber.dx,
        bobber.dy,
      );
    canvas.drawPath(
      line,
      stroke
        ..color = const Color(0x7a222739)
        ..strokeWidth = 2.8,
    );
    canvas.drawPath(
      line,
      stroke
        ..color = dangerous ? const Color(0xffffbb8a) : const Color(0xffd9f7f3)
        ..strokeWidth = 1.35,
    );

    final splash =
        biting || fighting || (phase == FishingPhase.waiting && moment < .85);
    final rings = splash ? 3 : 1;
    if (phase != FishingPhase.flight) {
      for (var i = 0; i < rings; i++) {
        final pulse = reduced ? .5 : (t * (splash ? 2.4 : 1.1) + i * .28) % 1;
        canvas.drawOval(
          Rect.fromCenter(
            center: bobber + const Offset(0, 4),
            width: 12 + pulse * (splash ? 49 : 26),
            height: 5 + pulse * 9,
          ),
          stroke
            ..color = const Color(
              0xffcef9ee,
            ).withValues(alpha: .65 * (1 - pulse))
            ..strokeWidth = 2,
        );
      }
      if (fighting) {
        final wake = Path()
          ..moveTo(bobber.dx, bobber.dy)
          ..quadraticBezierTo(
            bobber.dx + drift * 270,
            bobber.dy + 8,
            bobber.dx + drift * 520,
            bobber.dy + 13,
          );
        canvas.drawPath(
          wake,
          stroke
            ..color = const Color(0xa6a4ecf0)
            ..strokeWidth = 2,
        );
      }
    }
    canvas.drawOval(
      Rect.fromCenter(center: bobber, width: 10, height: 15),
      Paint()..color = const Color(0xff203343),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: bobber - const Offset(0, 2),
        width: 7.2,
        height: 10,
      ),
      Paint()
        ..color = biting ? const Color(0xffffbd49) : const Color(0xffff845a),
    );
    canvas.drawLine(
      bobber - const Offset(0, 8),
      bobber - const Offset(0, 2),
      stroke
        ..color = const Color(0xfffff1bf)
        ..strokeWidth = 2.4,
    );
  }

  @override
  bool shouldRepaint(_WaterPainter old) =>
      old.time != time ||
      old.bearing != bearing ||
      old.phase != phase ||
      old.reduced != reduced ||
      old.tension != tension;
}
