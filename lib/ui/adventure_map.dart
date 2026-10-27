import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/journey.dart';
import '../domain/course.dart';
import 'character_moment.dart';
import 'design.dart';
import 'flight_components.dart';
import 'journey_planet.dart';

const regionColors = [
  Color(0xFF168B92),
  Color(0xFF9171BD),
  Color(0xFF609267),
  Color(0xFFB3773B),
  Color(0xFF4078AA),
];

class AdventureMap extends ConsumerStatefulWidget {
  const AdventureMap({super.key});
  @override
  ConsumerState<AdventureMap> createState() => _AdventureMapState();
}

class _AdventureMapState extends ConsumerState<AdventureMap> {
  int? selected;
  final currentKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), catalog = app.repository.catalog;
    final current = catalog
        .where((l) => !app.progress.completed.contains(l.id))
        .firstOrNull;
    final region = JourneyRegion
        .all[selected ?? JourneyRegion.forOrder(current?.order ?? 19).index];
    final lessons = region.lessons(catalog).toList();
    final done = lessons
        .where((l) => app.progress.completed.contains(l.id))
        .length;
    final color = regionColors[region.index];
    final type = Theme.of(context).textTheme;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'АТЛАС ОТКРЫТИЙ',
          style: type.labelSmall?.copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 6),
        Text('Куда полетим?', style: type.headlineLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in JourneyRegion.all)
              ChoiceChip(
                key: ValueKey('map-world-${r.index}'),
                selected: region.index == r.index,
                showCheckmark: false,
                tooltip: r.title,
                label: Text('${r.index + 1}'),
                avatar: Icon(
                  r.complete(app.progress.completed, catalog)
                      ? Icons.check
                      : r.index >
                            JourneyRegion.forOrder(current?.order ?? 19).index
                      ? Icons.lock_outline
                      : Icons.public,
                  size: 18,
                ),
                onSelected: (_) => setState(() => selected = r.index),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: .3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!largeText)
                    ExcludeSemantics(
                      child: SizedBox(
                        width: 92,
                        height: 92,
                        child: CustomPaint(
                          painter: JourneyPlanetPainter(region.index, color),
                        ),
                      ),
                    ),
                  if (!largeText) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ОБЛАСТЬ ${region.index + 1} / 5',
                          style: type.labelSmall,
                        ),
                        Text(region.title, style: type.titleLarge),
                        Text(
                          '$done / ${lessons.length} миссии',
                          style: type.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(region.subtitle, style: type.titleMedium),
              const SizedBox(height: 10),
              FlightProgress(
                value: done,
                target: lessons.length,
                label: 'Исследовано в области',
              ),
              const SizedBox(height: 12),
              Text(region.invitation),
              if (region.index >
                  JourneyRegion.forOrder(current?.order ?? 19).index) ...[
                const SizedBox(height: 8),
                const Text(
                  'Пока это обзор будущей области. Продолжай текущий маршрут, чтобы открыть её миссии.',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CharacterMoment(
              characterId: region.guide,
              size: 42,
              animate: false,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Две короткие части в каждой миссии. Можно остановиться на контрольной точке.',
                style: type.bodySmall,
              ),
            ),
          ],
        ),
        for (final lesson in lessons) ...[
          SizedBox(
            height: 20,
            child: Center(
              child: Container(width: 2, color: color.withValues(alpha: .35)),
            ),
          ),
          _node(app, lesson, current?.id, color),
          if (lesson.order == lessons[1].order) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('map-practice'),
              onPressed: () => context.go('/practice'),
              icon: const Icon(Icons.psychology_outlined),
              label: const Text('Остановка памяти · до 3 слов'),
            ),
          ],
        ],
        const SizedBox(height: 20),
        FlightPanel(
          accent: true,
          child: Row(
            children: [
              Icon(
                done == lessons.length
                    ? Icons.workspace_premium
                    : Icons.flag_outlined,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  done == lessons.length
                      ? 'Область исследована! Печать в паспорте путешествий.'
                      : 'Финал области: ${region.subtitle.toLowerCase()}. Печать за все четыре миссии.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (current != null)
          TextButton.icon(
            onPressed: () {
              setState(
                () => selected = JourneyRegion.forOrder(current.order).index,
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final target = currentKey.currentContext;
                if (mounted && target != null) {
                  Scrollable.ensureVisible(
                    target,
                    alignment: .15,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 350),
                  );
                }
              });
            },
            icon: const Icon(Icons.my_location),
            label: const Text('К текущей миссии'),
          ),
        if (app.inventory.unopened > 0)
          TextButton.icon(
            onPressed: () => context.go('/rewards'),
            icon: const Icon(Icons.redeem),
            label: Text('Находки ждут: ${app.inventory.unopened}'),
          ),
        OutlinedButton.icon(
          onPressed: () => context.go('/expeditions'),
          icon: const Icon(Icons.explore_outlined),
          label: const Text('Паспорт и экспедиции'),
        ),
        const SizedBox(height: 10),
        Text(
          '${app.progress.completed.length} из ${catalog.length} миссий · вводный маршрут A1',
          textAlign: TextAlign.center,
          style: type.bodySmall,
        ),
      ],
    );
  }

  Widget _node(
    AppController app,
    LessonInfo lesson,
    String? current,
    Color accent,
  ) {
    final done = app.progress.completed.contains(lesson.id);
    final open =
        lesson.order == 0 ||
        done ||
        app.progress.completed.contains(
          app.repository.catalog[lesson.order - 1].id,
        );
    final active = current == lesson.id;
    return Padding(
      key: active ? currentKey : null,
      padding: EdgeInsets.only(
        left: lesson.order.isEven ? 0 : 22,
        right: lesson.order.isEven ? 22 : 0,
      ),
      child: Semantics(
        button: true,
        label:
            '${lesson.title}. ${done
                ? 'Пройдено'
                : open
                ? 'Доступно'
                : 'После предыдущей миссии'}',
        child: InkWell(
          key: ValueKey('map-lesson-${lesson.id}'),
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (!open) {
              showMessage(
                context,
                'Пройдите предыдущий урок, чтобы открыть эту орбиту.',
              );
              return;
            }
            context.go(
              app.installed.contains(lesson.id)
                  ? '/lesson/${lesson.id}'
                  : '/offline',
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: .12)
                  : Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: active
                    ? accent
                    : Theme.of(context).colorScheme.outlineVariant,
                width: active ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle
                      : open
                      ? Icons.play_arrow_rounded
                      : Icons.lock_outline,
                  color: open ? accent : null,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active
                            ? 'ТВОЙ СЛЕДУЮЩИЙ ШАГ'
                            : 'МИССИЯ ${lesson.order + 1}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        lesson.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        done
                            ? 'Пройдено · повторить'
                            : '2 этапа · есть точка отдыха',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
