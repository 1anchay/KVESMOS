import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/course.dart';

/// Static, deterministic scenery: no ticker, bitmap generation or network.
class GalaxyField extends StatelessWidget {
  final Widget child;
  final bool deep;
  const GalaxyField({super.key, required this.child, this.deep = false});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _GalaxyPainter(
      deep || Theme.of(context).brightness == Brightness.dark,
      deep,
    ),
    child: child,
  );
}

class _GalaxyPainter extends CustomPainter {
  final bool dark, deep;
  _GalaxyPainter(this.dark, this.deep);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  const Color(0xFF102450),
                  const Color(0xFF241444),
                  const Color(0xFF0B1934),
                ]
              : [
                  const Color(0xFFEAF5FF),
                  const Color(0xFFF4EEFF),
                  const Color(0xFFE9F6F5),
                ],
        ).createShader(rect),
    );
    final random = math.Random(37);
    for (var i = 0; i < 38; i++) {
      final p = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final paint = Paint()
        ..color = (dark ? Colors.white : const Color(0xFF7694C0)).withValues(
          alpha: dark ? .16 : .12,
        );
      canvas.drawCircle(p, i % 7 == 0 ? 2 : 1, paint);
    }
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (dark ? const Color(0xFF9A99FF) : const Color(0xFF98AFE0))
          .withValues(alpha: .16);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .9, size.height * .35),
        width: size.width * .9,
        height: 160,
      ),
      orbit,
    );
    if (deep) {
      canvas.drawCircle(
        Offset(size.width * .84, 80),
        58,
        Paint()
          ..shader =
              const RadialGradient(
                colors: [Color(0xFF6752C9), Color(0xFF30367E)],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(size.width * .84, 80),
                  radius: 58,
                ),
              ),
      );
    }
  }

  @override
  bool shouldRepaint(_GalaxyPainter old) =>
      old.dark != dark || old.deep != deep;
}

class MissionHeader extends StatelessWidget {
  final String eyebrow, title, subtitle;
  final IconData icon;
  const MissionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.icon = Icons.explore_rounded,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Compact, accessible overview of the entire expedition. All access decisions
/// remain with the existing course/controller rather than this visual map.
class JourneyConstellation extends StatelessWidget {
  final List<LessonInfo> lessons;
  final Set<String> completed;
  final void Function(LessonInfo) onOpen;
  const JourneyConstellation({
    super.key,
    required this.lessons,
    required this.completed,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final current = lessons.where((l) => !completed.contains(l.id)).firstOrNull;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: GalaxyField(
        deep: true,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ТВОЁ СОЗВЕЗДИЕ',
                style: TextStyle(
                  color: Color(0xFFAEEBFF),
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${completed.length} / ${lessons.length} миссий',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 0,
                  runSpacing: 8,
                  children: [
                    for (final lesson in lessons)
                      SizedBox(
                        width: constraints.maxWidth / 5,
                        height: 52,
                        child: Semantics(
                          label:
                              'Миссия ${lesson.order + 1}: ${lesson.title}. ${completed.contains(lesson.id)
                                  ? 'Пройдена'
                                  : current?.id == lesson.id
                                  ? 'Текущая'
                                  : 'Впереди'}',
                          button: true,
                          child: Tooltip(
                            message: lesson.title,
                            child: InkWell(
                              key: ValueKey('constellation-${lesson.id}'),
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => onOpen(lesson),
                              child: Center(
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: completed.contains(lesson.id)
                                        ? const Color(0xFF37D9AE)
                                        : current?.id == lesson.id
                                        ? const Color(0xFFFFD865)
                                        : const Color(0xFF283C62),
                                    border: Border.all(
                                      color: current?.id == lesson.id
                                          ? Colors.white
                                          : const Color(0xFF7792BC),
                                      width: current?.id == lesson.id ? 3 : 1,
                                    ),
                                    boxShadow: current?.id == lesson.id
                                        ? [
                                            const BoxShadow(
                                              color: Color(0x55FFD865),
                                              blurRadius: 14,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: ExcludeSemantics(
                                    child: completed.contains(lesson.id)
                                        ? const Icon(
                                            Icons.check_rounded,
                                            color: Color(0xFF092B30),
                                            size: 20,
                                          )
                                        : Text(
                                            '${lesson.order + 1}',
                                            textScaler: const TextScaler.linear(
                                              1,
                                            ),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: current?.id == lesson.id
                                                  ? const Color(0xFF242038)
                                                  : Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Каждая звезда — новый разговор',
                style: TextStyle(color: Color(0xFFD4DDF6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RewardBurst extends CustomPainter {
  final double progress;
  final Color color;
  final bool reduce;
  RewardBurst(this.progress, this.color, this.reduce);
  @override
  void paint(Canvas canvas, Size size) {
    if (reduce || progress <= .4 || progress >= 1) return;
    final t = ((progress - .4) / .6).clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withValues(alpha: 1 - t)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final direction = Offset(
        math.cos(i * math.pi / 6),
        math.sin(i * math.pi / 6),
      );
      canvas.drawLine(
        center + direction * (40 + 50 * t),
        center + direction * (50 + 75 * t),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RewardBurst old) =>
      progress != old.progress || color != old.color || reduce != old.reduce;
}

class StoryPanel extends StatelessWidget {
  final StoryBeat story;
  final bool completed;
  const StoryPanel({super.key, required this.story, required this.completed});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${story.title}, шаг ${story.step} из ${story.total}',
    child: Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ИСТОРИЯ КОМАНДЫ',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(story.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              story.total,
              (i) => Expanded(
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color:
                        i < story.step - 1 || (i == story.step - 1 && completed)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            completed && story.step == story.total
                ? 'История завершена — команда справилась!'
                : 'Шаг ${story.step} из ${story.total} · помоги команде',
          ),
        ],
      ),
    ),
  );
}

class AnswerTile extends StatelessWidget {
  final String text;
  final int index;
  final bool selected;
  final bool? verdict;
  final VoidCallback onPressed;
  const AnswerTile({
    super.key,
    required this.text,
    required this.index,
    required this.selected,
    this.verdict,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = verdict == false ? const Color(0xFFAC671C) : scheme.primary;
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 140),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22)),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 66),
            padding: const EdgeInsets.all(16),
            backgroundColor: selected
                ? accent.withValues(alpha: .14)
                : scheme.surfaceContainerLowest,
            foregroundColor: scheme.onSurface,
            side: BorderSide(
              color: selected ? accent : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          onPressed: onPressed,
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? accent : scheme.surfaceContainerHighest,
                  ),
                  child: selected
                      ? Icon(
                          verdict == false
                              ? Icons.close_rounded
                              : verdict == true
                              ? Icons.check_rounded
                              : Icons.radio_button_checked,
                          size: 18,
                          color: scheme.onPrimary,
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }
}
