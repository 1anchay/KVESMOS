import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/space_adventures.dart';
import 'character_moment.dart';

const stationInk = Color(0xFF101F35);
const stationMint = Color(0xFF8DE5CB);
const stationGold = Color(0xFFFFCF78);

IconData cargoIcon(String id) => switch (id) {
  'book' => Icons.menu_book_rounded,
  'pen' => Icons.edit_rounded,
  'bag' => Icons.backpack_rounded,
  'log' => Icons.auto_stories_rounded,
  'console' => Icons.settings_input_antenna_rounded,
  'bay' => Icons.inventory_2_outlined,
  'junction' => Icons.alt_route_rounded,
  _ => Icons.person_outline_rounded,
};
String objectName(String id) => switch (id) {
  'book' => 'Книга',
  'pen' => 'Ручка',
  'bag' => 'Шкаф с сумкой',
  'guide' => 'Собеседник',
  'log' => 'Журнал',
  'console' => 'Пульт',
  'bay' => 'Грузовой отсек',
  'junction' => 'Развилка',
  _ => id,
};
String roomName(String id) => switch (id) {
  'deck' => 'Палуба маяка',
  'radio' => 'Радиорубка',
  'workshop' => 'Мастерская Зига',
  'cargo' => 'Грузовой отсек',
  'arrival' => 'Зона прибытия',
  'terminal' => 'Терминалы стыковки',
  _ => 'Станция',
};

class SpaceStation extends StatelessWidget {
  final SpaceAdventure adventure;
  final AdventureState state;
  final bool quiet, busy;
  final void Function(String, double, double) move;
  const SpaceStation({
    super.key,
    required this.adventure,
    required this.state,
    required this.quiet,
    required this.busy,
    required this.move,
  });
  @override
  Widget build(BuildContext context) {
    final step =
        adventure.steps[state.step.clamp(0, adventure.steps.length - 1)];
    final objects = adventure.id == 'kit' && step.room == 'workshop'
        ? ['book', 'pen', 'bag']
        : [
            step.room == 'cargo' ? 'bay' : 'guide',
            'log',
            step.target == 'junction' ? 'junction' : 'console',
          ];
    if (!objects.contains(step.target)) objects[2] = step.target;
    const positions = [Offset(.20, .38), Offset(.76, .32), Offset(.68, .66)];
    return Semantics(
      label: 'Игровая локация: ${roomName(step.room)}',
      child: AspectRatio(
        aspectRatio: 1.16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: LayoutBuilder(
            builder: (context, box) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: busy
                          ? null
                          : (tap) => move(
                              '',
                              tap.localPosition.dx / box.maxWidth,
                              tap.localPosition.dy / box.maxHeight,
                            ),
                      child: CustomPaint(
                        painter: StationPainter(
                          adventure.id,
                          step.room,
                          state.resolved.length,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 14,
                    right: 18,
                    child: Text(
                      roomName(step.room).toUpperCase(),
                      style: const TextStyle(
                        color: stationMint,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  for (var i = 0; i < objects.length; i++)
                    Positioned(
                      left: positions[i].dx * box.maxWidth - 28,
                      top: positions[i].dy * box.maxHeight - 28,
                      child: Semantics(
                        label:
                            '${objectName(objects[i])}${objects[i] == step.target ? ", цель задания" : ""}',
                        button: true,
                        child: Tooltip(
                          message: objectName(objects[i]),
                          child: InkResponse(
                            key: ValueKey('object-${objects[i]}'),
                            onTap: busy
                                ? null
                                : () => move(
                                    objects[i],
                                    positions[i].dx,
                                    (positions[i].dy + .18).clamp(.2, .88),
                                  ),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: state.focus == objects[i]
                                    ? stationGold
                                    : const Color(0xFF29495C),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  width: 2,
                                  color: objects[i] == step.target
                                      ? stationMint
                                      : const Color(0xFF547283),
                                ),
                              ),
                              child: objects[i] == 'guide'
                                  ? IgnorePointer(
                                      child: CharacterMoment(
                                        characterId: adventure.guide,
                                        size: 50,
                                        animate: !quiet,
                                        state: CharacterState.greeting,
                                      ),
                                    )
                                  : Icon(
                                      cargoIcon(objects[i]),
                                      color: state.focus == objects[i]
                                          ? stationInk
                                          : Colors.white,
                                      size: 30,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  AnimatedPositioned(
                    duration: quiet
                        ? Duration.zero
                        : const Duration(milliseconds: 450),
                    curve: Curves.easeInOutCubic,
                    left: state.x * box.maxWidth - 24,
                    top: state.y * box.maxHeight - 30,
                    child: IgnorePointer(
                      child: CharacterMoment(
                        characterId: 'orbi',
                        size: 48,
                        animate: !quiet,
                        state: state.dialogue.startsWith('Попробуем')
                            ? CharacterState.support
                            : CharacterState.idle,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Original lightweight vector set, no new bitmap assets or perpetual ticker.
class StationPainter extends CustomPainter {
  final String adventure, room;
  final int resolved;
  StationPainter(this.adventure, this.room, this.resolved);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ink = Paint()..color = stationInk;
    canvas.drawRect(Offset.zero & size, ink);
    final floor = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, h * .2, w - 24, h * .73),
      const Radius.circular(20),
    );
    ink.color = adventure == 'kit'
        ? const Color(0xFF28333F)
        : const Color(0xFF1C3448);
    canvas.drawRRect(floor, ink);
    canvas.save();
    canvas.clipRRect(floor);
    ink
      ..color = const Color(0xFF355064)
      ..strokeWidth = 1;
    for (double x = -h; x < w + h; x += 42) {
      canvas.drawLine(Offset(x, h * .2), Offset(x + h * .5, h), ink);
    }
    for (double y = h * .2; y < h; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(w, y), ink);
    }
    canvas.restore();
    // Star windows, equipment conduits and room-specific silhouettes.
    ink.color = const Color(0xFF060F21);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .38, h * .15, w * .47, h * .13),
        const Radius.circular(12),
      ),
      ink,
    );
    ink.color = stationMint;
    for (var i = 0; i < 8; i++) {
      canvas.drawCircle(
        Offset(w * (.41 + i * .054), h * (.19 + (i % 3) * .023)),
        1.3,
        ink,
      );
    }
    ink
      ..color = stationGold
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(w * .2, h * .45)
      ..lineTo(w * .2, h * .78)
      ..lineTo(w * .68, h * .78)
      ..lineTo(w * .68, h * .66);
    canvas.drawPath(path, ink);
    ink
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF496271);
    if (adventure == 'kit') {
      for (var i = 0; i < 3; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * (.18 + i * .18), h * .53, 28, 17),
            const Radius.circular(4),
          ),
          ink,
        );
      }
    } else if (adventure == 'port') {
      final shipX = w * (.30 + math.min(resolved, 4) * .07);
      final ship = Path()
        ..moveTo(shipX, h * .50)
        ..lineTo(shipX - 16, h * .60)
        ..lineTo(shipX + 16, h * .60)
        ..close();
      ink.color = stationGold;
      canvas.drawPath(ship, ink);
    } else {
      ink
        ..style = PaintingStyle.stroke
        ..color = stationMint
        ..strokeWidth = 2;
      for (var i = 1; i <= 3; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset(w * .4, h * .48), radius: 7.0 * i),
          -.8,
          1.6,
          false,
          ink,
        );
      }
    }
    ink
      ..style = PaintingStyle.fill
      ..color = stationMint;
    for (var i = 0; i < resolved; i++) {
      canvas.drawCircle(Offset(22.0 + i * 12, h - 12), 3, ink);
    }
  }

  @override
  bool shouldRepaint(StationPainter old) =>
      old.adventure != adventure ||
      old.room != room ||
      old.resolved != resolved;
}
