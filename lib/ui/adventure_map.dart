import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/course.dart';
import 'character_reactions.dart';
import 'design.dart';

const _worldNames = [
  'Маяк первого контакта',
  'Острова простых слов',
  'Кольца чисел',
  'Тёплая планета',
  'Космическое кафе',
  'Туманность красок',
  'Станция нового дня',
  'Академия открытий',
  'Порт путешествий',
  'Созвездие диалогов',
];
const _worldColors = [
  cosmicBlue,
  Color(0xFF087E9B),
  violet,
  Color(0xFFBD6044),
  Color(0xFF995523),
];

class AdventureMap extends ConsumerStatefulWidget {
  const AdventureMap({super.key});
  @override
  ConsumerState<AdventureMap> createState() => _AdventureMapState();
}

class _AdventureMapState extends ConsumerState<AdventureMap> {
  final _currentKey = GlobalKey();
  void _openLesson(AppController app, LessonInfo lesson) => context.go(
    app.installed.contains(lesson.id) ? '/lesson/${lesson.id}' : '/offline',
  );
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), catalog = app.repository.catalog;
    final completed = app.progress.completed;
    final current = catalog.where((l) => !completed.contains(l.id)).firstOrNull;
    final done = catalog.where((l) => completed.contains(l.id)).length;
    final groups = <List<LessonInfo>>[];
    for (final lesson in catalog) {
      if (groups.isEmpty ||
          groups.last.first.topic != lesson.topic ||
          groups.last.first.section != lesson.section) {
        groups.add([]);
      }
      groups.last.add(lesson);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'Маршрут по галактике',
          subtitle: 'От первого сигнала до самостоятельного разговора.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$done из ${catalog.length} остановок освоено',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: catalog.isEmpty ? 0 : done / catalog.length,
                  minHeight: 8,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _legend(Icons.navigation_rounded, 'Текущий'),
                    _legend(Icons.check_circle, 'Пройден'),
                    _legend(Icons.lock_outline, 'Впереди'),
                  ],
                ),
                const SizedBox(height: 14),
                if (current != null)
                  FilledButton.icon(
                    onPressed: () {
                      final target = _currentKey.currentContext;
                      if (target != null) {
                        Scrollable.ensureVisible(
                          target,
                          alignment: .15,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 450),
                        );
                      }
                    },
                    icon: const Icon(Icons.my_location),
                    label: const Text('К текущему уроку'),
                  )
                else if (catalog.isNotEmpty) ...[
                  const Text(
                    'Курс пройден! Все планеты открыты. Можно повторить любую остановку.',
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _openLesson(app, catalog.first),
                    icon: const Icon(Icons.replay),
                    label: const Text('Повторить первый урок'),
                  ),
                ],
              ],
            ),
          ),
        ),
        for (var group = 0; group < groups.length; group++) ...[
          const SizedBox(height: 24),
          _WorldHeader(
            key: ValueKey('map-world-$group'),
            index: group,
            topic: groups[group].first.topic,
            section: groups[group].first.section,
            done: groups[group].where((l) => completed.contains(l.id)).length,
            total: groups[group].length,
          ),
          if ({0, 2, 5}.contains(group))
            ExpansionTile(
              key: ValueKey('map-guide-$group'),
              title: Text('На связи: ${_guide(group).name}'),
              leading: CharacterPortrait(_guide(group).id, size: 40),
              children: [
                CharacterReaction(
                  cue: _guide(group),
                  eventKey: 'map-guide-$group',
                  announce: false,
                ),
              ],
            ),
          for (final lesson in groups[group])
            _stop(
              context,
              app,
              lesson,
              current?.id,
              lesson.order == catalog.last.order,
            ),
        ],
      ],
    );
  }

  Widget _legend(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 16), const SizedBox(width: 5), Text(text)],
  );
  CharacterCue _guide(int group) => switch (group) {
    0 => CharacterCue.navigator,
    2 => CharacterCue.engineer,
    _ => CharacterCue.words,
  };

  Widget _stop(
    BuildContext context,
    AppController app,
    LessonInfo lesson,
    String? currentId,
    bool last,
  ) {
    final completed = app.progress.completed.contains(lesson.id);
    // Keep the existing lesson access rule; the lesson screen checks it too.
    final unlocked =
        lesson.order == 0 ||
        completed ||
        app.progress.completed.contains(
          app.repository.catalog[lesson.order - 1].id,
        );
    final current = lesson.id == currentId;
    final accent = _worldColors[(lesson.order ~/ 2) % _worldColors.length];
    final milestone = app.rewards.catalog.milestones
        .where((m) => m['unique_lesson_count'] == lesson.order + 1)
        .firstOrNull;
    final status = completed
        ? 'Пройден · можно повторить'
        : current
        ? 'Текущий урок'
        : unlocked
        ? 'Можно отправляться'
        : 'После предыдущего урока';
    final railColor = completed
        ? mintGlow
        : current
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(width: 3, height: 18, color: railColor),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed
                        ? mintGlow
                        : current
                        ? accent
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: Border.all(color: railColor, width: 2),
                  ),
                  child: Icon(
                    completed
                        ? Icons.check
                        : current
                        ? Icons.navigation_rounded
                        : unlocked
                        ? Icons.circle_outlined
                        : Icons.lock_outline,
                    size: 18,
                    color: completed
                        ? space
                        : current
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!last)
                  Expanded(child: Container(width: 3, color: railColor)),
                if (!last)
                  Icon(Icons.keyboard_arrow_down, color: railColor, size: 18),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: current ? _currentKey : null,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('focus:${lesson.id}:$current'),
                      tween: Tween(begin: 0, end: 1),
                      duration:
                          current && !MediaQuery.disableAnimationsOf(context)
                          ? const Duration(milliseconds: 420)
                          : Duration.zero,
                      builder: (_, t, child) => Transform.scale(
                        scale: current ? 1 + math.sin(math.pi * t) * .015 : 1,
                        child: child,
                      ),
                      child: Card(
                        key: ValueKey('map-lesson-${lesson.id}'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                          side: BorderSide(
                            color: current
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: current ? 2.5 : .6,
                          ),
                        ),
                        child: Semantics(
                          label: status,
                          child: InkWell(
                            onTap: () => unlocked
                                ? _openLesson(app, lesson)
                                : showMessage(
                                    context,
                                    'Пройдите предыдущий урок, чтобы открыть эту орбиту.',
                                  ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ОСТАНОВКА ${lesson.order + 1}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    lesson.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    status,
                                    style: TextStyle(
                                      fontWeight: current
                                          ? FontWeight.w800
                                          : FontWeight.w400,
                                      color: current
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                  if (current) ...[
                                    const SizedBox(height: 10),
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.play_circle_outline,
                                          size: 20,
                                        ),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text('Начать или продолжить'),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (unlocked &&
                                      !app.installed.contains(lesson.id))
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Сначала сохраните урок для офлайн-обучения',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (milestone != null) ...[
                    const SizedBox(height: 8),
                    _MilestoneStop(
                      milestone: milestone,
                      earned: app.inventory.grants.containsKey(milestone['id']),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _lessonCount(int n) {
  final last = n % 10, pair = n % 100;
  final word = pair >= 11 && pair <= 14
      ? 'уроков'
      : last == 1
      ? 'урок'
      : last >= 2 && last <= 4
      ? 'урока'
      : 'уроков';
  return '$n $word';
}

class _MilestoneStop extends StatelessWidget {
  final Map<String, dynamic> milestone;
  final bool earned;
  const _MilestoneStop({required this.milestone, required this.earned});
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: InkWell(
      key: ValueKey('map-reward-${milestone['id']}'),
      onTap: earned
          ? () => context.go('/rewards')
          : () => showMessage(
              context,
              'Сундук за разные завершённые уроки. Рубеж: ${_lessonCount(milestone['unique_lesson_count'])}.',
            ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Image.asset(
              'assets/kvesmos/${milestone['chest_id']}_closed.png',
              width: 46,
              height: 46,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Рубеж: ${_lessonCount(milestone['unique_lesson_count'])}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    earned
                        ? 'Сундук заработан · посмотреть'
                        : 'За разные уроки · впереди',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              earned ? Icons.check_circle_outline : Icons.star_outline,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

class _WorldHeader extends StatelessWidget {
  final int index, done, total;
  final String topic, section;
  const _WorldHeader({
    super.key,
    required this.index,
    required this.topic,
    required this.section,
    required this.done,
    required this.total,
  });
  @override
  Widget build(BuildContext context) {
    final color = _worldColors[index % _worldColors.length];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [color.withValues(alpha: .19), color.withValues(alpha: .04)],
        ),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: CustomPaint(painter: _PlanetPainter(index, color)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ПЛАНЕТА ${index + 1}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      index < _worldNames.length ? _worldNames[index] : topic,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(topic, style: Theme.of(context).textTheme.titleMedium),
          Text(section),
          const SizedBox(height: 10),
          Text(
            done == total
                ? 'Планета исследована · $done / $total'
                : 'Остановки: $done / $total',
          ),
        ],
      ),
    );
  }
}

/// Original Flutter geometry, no new bitmap assets or generation service.
class _PlanetPainter extends CustomPainter {
  final int index;
  final Color color;
  const _PlanetPainter(this.index, this.color);
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
  bool shouldRepaint(_PlanetPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.color != color;
}
