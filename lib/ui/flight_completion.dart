import '../domain/explorer_profile.dart';
import 'collection_components.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/course.dart';
import '../domain/progress.dart';
import '../domain/today.dart';
import '../domain/journey.dart';
import 'journey_planet.dart';
import 'adventure_map.dart';
import 'character_moment.dart';
import 'flight_components.dart';
import 'today_page.dart';
import 'design.dart';
import 'character_reactions.dart' show hasDailyXpRecord;

class FlightCompletion extends StatelessWidget {
  final AppController app;
  final Lesson lesson;
  final ProgressSnapshot summary;
  final bool celebrate;
  final int newChests, bestCombo;
  final List<String> achievements;
  const FlightCompletion({
    super.key,
    required this.app,
    required this.lesson,
    required this.summary,
    required this.celebrate,
    required this.newChests,
    required this.bestCombo,
    required this.achievements,
  });
  @override
  Widget build(BuildContext context) {
    final today = TodayJourney(app.progress, app.repository.now(), app.goal);
    final type = Theme.of(context).textTheme;
    final region = JourneyRegion.forOrder(lesson.order);
    final regionDone = region.complete(
      app.progress.completed,
      app.repository.catalog,
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'На сегодня',
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: pageBody([
          FlightArrival(
            animate: celebrate && app.audio.preferences.reactions,
            child: Column(
              children: [
                CharacterMoment(
                  characterId: 'orbi',
                  state: CharacterState.celebration,
                  size: 92,
                  animate: celebrate && app.audio.preferences.reactions,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ещё одно открытие!',
                  style: type.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(lesson.title, style: type.bodyLarge),
                const SizedBox(height: 12),
                Text(
                  '+${summary.xp} XP',
                  key: const Key('earned-xp'),
                  style: type.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  '${summary.correct} верных ответов · всё сохранено',
                  style: type.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (celebrate &&
              hasDailyXpRecord(app.progress, app.repository.now())) ...[
            CollectionPanel(
              child: Row(
                children: [
                  const Icon(Icons.insights_rounded, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Новый личный рекорд!', style: type.titleMedium),
                        Text(
                          '${today.xp} XP за сегодня — больше, чем в любой прошлый день.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (regionDone && lesson.order % 4 == 3) ...[
            FlightArrival(
              animate: celebrate && app.audio.preferences.reactions,
              child: FlightPanel(
                accent: true,
                child: Column(
                  children: [
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: CustomPaint(
                        painter: JourneyPlanetPainter(
                          region.index,
                          regionColors[region.index],
                        ),
                      ),
                    ),
                    Text(
                      '${region.title}: исследовано!',
                      style: type.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      region.index < 4
                          ? 'Новая область открыта: ${JourneyRegion.all[region.index + 1].title}. Печать уже в паспорте.'
                          : 'Все пять печатей собраны. Вводный маршрут пройден — продолжай закреплять слова.',
                    ),
                    TextButton(
                      onPressed: () => context.go('/map'),
                      child: const Text('Посмотреть новую область'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          FlightPanel(
            accent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  today.mood == TodayMood.complete
                      ? 'Цель дня — готово!'
                      : 'Ты ближе к цели дня',
                  style: type.titleMedium,
                ),
                const SizedBox(height: 8),
                FlightProgress(
                  value: today.xp,
                  target: today.goal,
                  label: 'Цель дня',
                ),
                const SizedBox(height: 8),
                Text(
                  '${today.xp} / ${today.goal} XP · ${today.streak} дн. вместе',
                ),
                if (newChests > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Заработано сундуков: $newChests',
                    style: type.titleMedium,
                  ),
                  const Text(
                    'За урок и задания дня. Они уже в твоих находках.',
                  ),
                ],
                for (final achievement in achievements)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FlightArrival(
                      animate: celebrate && app.audio.preferences.reactions,
                      child: Row(
                        children: [
                          BadgeArt(
                            ExplorerBadge.all.firstWhere(
                              (b) => b.name == achievement,
                            ),
                            size: 64,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextButton(
                              onPressed: () => context.go('/achievements'),
                              child: Text(achievement, style: type.titleMedium),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (lesson.objective != null)
            Text(
              'Теперь ты умеешь: ${lesson.objective}',
              style: type.bodyLarge,
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.go(
              app.progress.completed.length == app.repository.catalog.length
                  ? '/review'
                  : nextLessonRoute(app),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              app.progress.completed.length == app.repository.catalog.length
                  ? 'Короткое повторение'
                  : 'Следующая миссия',
            ),
          ),
          if (app.inventory.unopened > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () => context.go('/rewards'),
                icon: const Icon(Icons.redeem_rounded),
                label: const Text('Открыть находки'),
              ),
            ),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('На сегодня достаточно'),
          ),
          if (summary.errors > 0) ...[
            const SizedBox(height: 8),
            const Text(
              'Ошибки подсказали, что повторить. XP остаются с тобой.',
            ),
            TextButton(
              onPressed: () => context.go('/review?mistakes=1'),
              child: const Text('Разобрать ошибки сейчас'),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              Text(
                summary.correct + summary.errors == 0
                    ? '—'
                    : '${(100 * summary.correct / (summary.correct + summary.errors)).round()}%',
                style: type.titleMedium,
              ),
              Text(
                'точность всех попыток · ошибок: ${summary.errors}',
                style: type.bodySmall,
              ),
            ],
          ),
          if (bestCombo > 1)
            Text(
              'Лучшая серия: $bestCombo ответов подряд',
              textAlign: TextAlign.center,
              style: type.bodySmall,
            ),
        ]),
      ),
    );
  }
}
