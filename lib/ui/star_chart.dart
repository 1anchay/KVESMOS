import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/journey.dart';
import 'journey_planet.dart';

class StarChart extends StatefulWidget {
  final List<JourneyRegion> regions;
  final int start;
  const StarChart({super.key, required this.regions, required this.start});

  @override
  State<StarChart> createState() => _StarChartState();
}

class _StarChartState extends State<StarChart> {
  final camera = TransformationController();
  late int selected = widget.start;
  bool centered = false;

  Offset point(int i) => Offset(108 + i * 152.0, 150 + 57 * math.sin(i * 1.65));

  void focus(Size viewport) {
    final target = point(selected);
    camera.value = Matrix4.translationValues(
      (viewport.width / 2 - target.dx)
          .clamp(math.min(0.0, viewport.width - chartWidth), 0.0)
          .toDouble(),
      (viewport.height / 2 - target.dy)
          .clamp(math.min(0.0, viewport.height - 340), 0.0)
          .toDouble(),
      0,
    );
  }

  double get chartWidth => point(widget.regions.length - 1).dx + 108;

  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = widget.regions[selected];
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 700);
    return Scaffold(
      appBar: AppBar(title: const Text('Звёздная карта')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) {
                  if (!centered) {
                    centered = true;
                    focus(bounds.biggest);
                  }
                  final width = math.max(chartWidth, bounds.maxWidth);
                  final height = math.max(340.0, bounds.maxHeight);
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(
                          color: const Color(0xff101b35),
                          child: InteractiveViewer(
                            transformationController: camera,
                            constrained: false,
                            minScale: .65,
                            maxScale: 3,
                            child: SizedBox(
                              width: width,
                              height: height,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _StarRoute([
                                        for (
                                          var i = 0;
                                          i < widget.regions.length;
                                          i++
                                        )
                                          point(i),
                                      ]),
                                    ),
                                  ),
                                  for (final world in widget.regions)
                                    Positioned(
                                      left: point(world.index).dx - 60,
                                      top: point(world.index).dy - 50,
                                      width: 120,
                                      child: Semantics(
                                        selected: selected == world.index,
                                        button: true,
                                        label: world.title,
                                        child: InkWell(
                                          onTap: () => setState(
                                            () => selected = world.index,
                                          ),
                                          child: Column(
                                            children: [
                                              SizedBox(
                                                width: 92,
                                                height: 92,
                                                child: JourneyPlanet(
                                                  world.index,
                                                ),
                                              ),
                                              Text(
                                                '${world.index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  AnimatedPositioned(
                                    duration: duration,
                                    curve: Curves.easeInOut,
                                    left: point(selected).dx + 27,
                                    top: point(selected).dy - 64,
                                    child: const IgnorePointer(
                                      child: Icon(
                                        Icons.rocket_launch,
                                        color: Color(0xffffd494),
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: IconButton.filledTonal(
                          tooltip: 'К выбранной планете',
                          onPressed: () => focus(bounds.biggest),
                          icon: const Icon(Icons.my_location),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    region.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: const Text('Открыть область'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRoute extends CustomPainter {
  final List<Offset> points;
  _StarRoute(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(57);
    final paint = Paint()..color = const Color(0xff8294b6);
    for (var i = 0; i < size.width / 4; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() + .4,
        paint,
      );
    }
    paint
      ..color = const Color(0xff659299)
      ..strokeWidth = 2;
    for (var i = 1; i < points.length; i++) {
      final from = points[i - 1], to = points[i];
      for (var j = 0; j < 12; j += 2) {
        canvas.drawLine(
          Offset.lerp(from, to, j / 12)!,
          Offset.lerp(from, to, (j + 1) / 12)!,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StarRoute old) => old.points.length != points.length;
}
