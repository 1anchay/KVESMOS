import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/explorer_profile.dart';

const collectionInk = Color(0xFF142F3B);
const collectionMint = Color(0xFF82E6CD);
const collectionGold = Color(0xFFF6CA72);

/// Bounded decoding, a useful label, and a quiet fallback for offline art errors.
class CollectionArt extends StatelessWidget {
  final String asset, label;
  final double size;
  const CollectionArt(
    this.asset, {
    super.key,
    required this.label,
    this.size = 120,
  });
  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
      64,
      900,
    ),
    semanticLabel: label,
    errorBuilder: (_, _, _) => SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Semantics(
          label: '$label · изображение недоступно',
          child: const Icon(Icons.auto_awesome_outlined, size: 42),
        ),
      ),
    ),
  );
}

class CollectionPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const CollectionPanel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(18),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color:
          color ??
          (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1D3540)
              : Colors.white),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .55),
      ),
    ),
    child: child,
  );
}

class CollectionHeading extends StatelessWidget {
  final String eyebrow, title;
  final Widget? trailing;
  const CollectionHeading(this.eyebrow, this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Original KVESMOS vector medals: orbital enamel, six distinct silhouettes.
/// Canvas art stays sharp at large text sizes; no external/generated imagery.
class BadgeArt extends StatelessWidget {
  final ExplorerBadge badge;
  final bool unlocked;
  final double size;
  const BadgeArt(this.badge, {super.key, this.unlocked = true, this.size = 90});
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${badge.name}, ступень ${badge.tier}, ${unlocked ? 'получено' : 'закрыто'}',
    image: true,
    child: CustomPaint(
      size: Size.square(size),
      painter: _BadgePainter(
        ExplorerBadge.all.indexOf(badge),
        unlocked,
        badge.tier,
      ),
    ),
  );
}

class _BadgePainter extends CustomPainter {
  final int index, tier;
  final bool unlocked;
  _BadgePainter(this.index, this.unlocked, this.tier);
  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 100, size.height / 100);
    const colors = [
      Color(0xFF208D83),
      Color(0xFF376FAC),
      Color(0xFF7761B4),
      Color(0xFFBE7651),
      Color(0xFF4D966A),
      Color(0xFFBD8B30),
    ];
    final color = unlocked ? colors[index] : const Color(0xFF82929B);
    final gold = unlocked ? collectionGold : const Color(0xFFBBC6CC);
    final ink = unlocked ? collectionInk : const Color(0xFF5D717C);
    final fill = Paint()..color = color;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final shield = Path()
      ..moveTo(50, 3)
      ..lineTo(85, 18)
      ..lineTo(89, 56)
      ..quadraticBezierTo(79, 83, 50, 96)
      ..quadraticBezierTo(21, 83, 11, 56)
      ..lineTo(15, 18)
      ..close();
    c.drawPath(shield, fill..color = ink);
    c.save();
    c.translate(5, 5);
    c.scale(.9);
    c.drawPath(shield, fill..color = color);
    c.drawPath(shield, line..color = gold);
    c.restore();
    c.drawArc(
      const Rect.fromLTWH(24, 18, 52, 52),
      -2.8,
      2.1,
      false,
      line
        ..color = Colors.white.withValues(alpha: .25)
        ..strokeWidth = 1.5,
    );
    void star(double x, double y, double r, Color col) {
      final p = Path();
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4 - math.pi / 2, d = i.isEven ? r : r * .3;
        if (i == 0) {
          p.moveTo(x + math.cos(a) * d, y + math.sin(a) * d);
        } else {
          p.lineTo(x + math.cos(a) * d, y + math.sin(a) * d);
        }
      }
      c.drawPath(p..close(), fill..color = col);
    }

    line
      ..strokeWidth = 3
      ..color = gold;
    switch (index) {
      case 0: // First radio contact.
        c.drawCircle(const Offset(50, 47), 6, fill..color = gold);
        for (final d in [15.0, 25.0]) {
          final r = Rect.fromCircle(center: const Offset(50, 47), radius: d);
          c.drawArc(r, -.85, 1.7, false, line);
          c.drawArc(r, math.pi - .85, 1.7, false, line);
        }
        c.drawLine(const Offset(50, 53), const Offset(43, 65), line);
        star(70, 24, 5, Colors.white);
      case 1: // Exploration ship.
        final rocket = Path()
          ..moveTo(50, 20)
          ..quadraticBezierTo(70, 34, 62, 57)
          ..lineTo(38, 57)
          ..quadraticBezierTo(30, 34, 50, 20)
          ..close();
        c.drawPath(rocket, fill..color = gold);
        c.drawCircle(const Offset(50, 38), 7, fill..color = ink);
        c.drawPath(
          Path()
            ..moveTo(38, 45)
            ..lineTo(27, 62)
            ..lineTo(40, 59)
            ..close(),
          fill..color = gold,
        );
        c.drawPath(
          Path()
            ..moveTo(62, 45)
            ..lineTo(73, 62)
            ..lineTo(60, 59)
            ..close(),
          fill,
        );
        c.drawPath(
          Path()
            ..moveTo(44, 62)
            ..lineTo(50, 74)
            ..lineTo(56, 62)
            ..close(),
          fill..color = Colors.white,
        );
      case 2: // Planet, not a stock icon.
        c.drawCircle(const Offset(50, 45), 19, fill..color = gold);
        c.drawCircle(
          const Offset(44, 38),
          5,
          fill..color = color.withValues(alpha: .6),
        );
        c.save();
        c.translate(50, 47);
        c.rotate(-.4);
        c.drawOval(
          const Rect.fromLTWH(-32, -9, 64, 18),
          line..color = Colors.white,
        );
        c.restore();
        star(73, 23, 5, gold);
      case 3: // Four-star route.
        const points = [
          Offset(28, 52),
          Offset(43, 27),
          Offset(70, 37),
          Offset(57, 64),
        ];
        for (var i = 0; i < 3; i++) {
          c.drawLine(points[i], points[i + 1], line..strokeWidth = 2);
        }
        for (final p in points) {
          star(p.dx, p.dy, 8, gold);
        }
      case 4: // Open field journal.
        c.drawPath(
          Path()
            ..moveTo(50, 34)
            ..quadraticBezierTo(36, 24, 26, 30)
            ..lineTo(26, 60)
            ..quadraticBezierTo(40, 56, 50, 66)
            ..quadraticBezierTo(60, 56, 74, 60)
            ..lineTo(74, 30)
            ..quadraticBezierTo(64, 24, 50, 34)
            ..close(),
          fill..color = gold,
        );
        c.drawLine(
          const Offset(50, 36),
          const Offset(50, 61),
          line
            ..color = ink
            ..strokeWidth = 2,
        );
        for (final y in [39.0, 46.0, 53.0]) {
          c.drawLine(Offset(32, y), Offset(42, y + 2), line);
          c.drawLine(Offset(58, y + 2), Offset(68, y), line);
        }
      default:
        star(50, 44, 26, gold);
        star(28, 27, 5, Colors.white);
        star(75, 59, 5, Colors.white);
        c.drawCircle(const Offset(50, 44), 7, fill..color = Colors.white);
    }
    for (var i = 0; i < tier; i++) {
      c.drawCircle(
        Offset(50 + (i - (tier - 1) / 2) * 8, 81),
        2.2,
        fill..color = gold,
      );
    }
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.index != index || old.unlocked != unlocked || old.tier != tier;
}

/// Static orbit lines; motion is driven by a single event controller upstream.
class RewardOrbitPainter extends CustomPainter {
  final double progress;
  final Color color;
  const RewardOrbitPainter(this.progress, this.color);
  @override
  void paint(Canvas c, Size size) {
    final center = Offset(size.width / 2, size.height / 2),
        radius = math.min(size.width, size.height) * .4;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      p.color = color.withValues(alpha: .08 + i * .03);
      c.drawCircle(center, radius * (.72 + i * .24), p);
    }
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 + .15;
      final d = radius * (.9 + .18 * math.sin(progress * math.pi));
      final start = center + Offset(math.cos(angle) * d, math.sin(angle) * d);
      final end =
          center +
          Offset(
            math.cos(angle) * (d + 8 + progress * 12),
            math.sin(angle) * (d + 8 + progress * 12),
          );
      c.drawLine(
        start,
        end,
        p
          ..color = color.withValues(alpha: .22 + progress * .35)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(RewardOrbitPainter old) =>
      old.progress != progress || old.color != color;
}
