import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'character_moment.dart';
import 'galaxy_components.dart';
import 'journey_planet.dart';

/// The bridge reflects completed learning. It has no separate reward ledger.
class CommandBridge extends StatelessWidget {
  final Widget companion;
  final int completed;
  final bool animate;
  const CommandBridge({
    super.key,
    required this.companion,
    required this.completed,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: SizedBox(
      height: 104,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GalaxyField(
            child: CustomPaint(
              painter: _BridgeInterior(
                Theme.of(context).brightness == Brightness.dark,
                completed,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x660A1630),
                  Color(0x000A1630),
                  Color(0xAA0A1630),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 66,
            top: 12,
            child: Text(
              'МОСТИК · ${completed == 0 ? 'ПЕРВЫЙ СИГНАЛ' : 'СВЯЗЬ УСТАНОВЛЕНА'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(right: 20, bottom: 8, child: companion),
          Positioned(
            left: 14,
            bottom: 8,
            child: Tooltip(
              message: 'Мико · тренировочная орбита',
              child: Semantics(
                button: true,
                label: 'Мико · открыть практику',
                child: InkWell(
                  onTap: () => context.go('/training'),
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: CharacterMoment(
                        characterId: 'miko',
                        size: 64,
                        animate: animate,
                        state: completed > 0
                            ? CharacterState.greeting
                            : CharacterState.thinking,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 5,
            child: IconButton(
              tooltip: 'Открыть карту галактики',
              onPressed: () => context.go('/galaxy'),
              icon: const Icon(Icons.explore_outlined, color: Colors.white),
            ),
          ),
          if (completed >= 4)
            Positioned(
              left: 100,
              bottom: 18,
              child: Tooltip(
                message: 'Завершено не менее четырёх учебных миссий',
                child: Image.asset(
                  'assets/kvesmos/explorer_closed.png',
                  width: 48,
                  height: 44,
                  excludeFromSemantics: true,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _BridgeInterior extends CustomPainter {
  final bool dark;
  final int completed;
  const _BridgeInterior(this.dark, this.completed);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()..color = const Color(0xFF20304D);
    final window = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 4, size.width - 16, size.height - 20),
      const Radius.circular(35),
    );
    canvas.drawRRect(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = dark ? const Color(0xFF334663) : const Color(0xFF8290AD),
    );
    canvas.save();
    canvas.translate(size.width * .53, 20);
    JourneyPlanetPainter(
      completed ~/ 4,
      const Color(0xFF168B92),
    ).paint(canvas, const Size(82, 82));
    canvas.restore();
    final deck = Path()
      ..moveTo(0, size.height - 28)
      ..lineTo(size.width * .3, size.height - 39)
      ..lineTo(size.width * .7, size.height - 39)
      ..lineTo(size.width, size.height - 28)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(deck, frame);
    for (final left in [false, true]) {
      final x = left ? 10.0 : size.width - 63;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - 30, 53, 17),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFF435976),
      );
      canvas.drawLine(
        Offset(x + 8, size.height - 23),
        Offset(x + 44, size.height - 23),
        Paint()
          ..color = const Color(0xFF74E6E2)
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_BridgeInterior old) =>
      old.dark != dark || old.completed != completed;
}
