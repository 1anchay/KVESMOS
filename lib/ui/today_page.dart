import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/missions.dart';
import '../domain/today.dart';
import '../domain/journey.dart';
import '../domain/progress.dart';
import '../services/learning_audio.dart';
import 'character_moment.dart';
import 'flight_components.dart';
import 'design.dart';

String nextLessonRoute(AppController app) {
  final next =
      app.repository.catalog
          .where((l) => !app.progress.completed.contains(l.id))
          .firstOrNull ??
      app.repository.catalog.first;
  return app.installed.contains(next.id) ? '/lesson/${next.id}' : '/offline';
}

bool reviewReadyToday(AppController app) => app.progress.words.values.any(
  (word) =>
      word.next != null && !word.next!.isAfter(app.repository.now().toUtc()),
);

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});
  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  String? checkedDay;
  bool greet = false;
  void arrival(AppController app, String day) {
    if (checkedDay == day) return;
    checkedDay = day;
    greet = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final fresh = await app.claimExperienceMoment('arrival:$day');
        if (mounted && checkedDay == day) setState(() => greet = fresh);
      } catch (_) {
        // A cosmetic greeting must not block a lesson if storage is unavailable.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final day = dayKey(app.repository.now());
    arrival(app, day);
    final today = TodayJourney(app.progress, app.repository.now(), app.goal);
    final next =
        app.repository.catalog
            .where((l) => !app.progress.completed.contains(l.id))
            .firstOrNull ??
        app.repository.catalog.first;
    final type = Theme.of(context).textTheme;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
    final companion = CharacterMoment(
      key: ValueKey((day, greet, today.mood)),
      characterId: 'orbi',
      size: largeText ? 56 : 88,
      animate: greet && app.audio.preferences.reactions,
      state: today.mood == TodayMood.complete
          ? CharacterState.celebration
          : today.mood == TodayMood.returning
          ? CharacterState.support
          : CharacterState.greeting,
    );
    final greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'СЕГОДНЯ · ${today.streak} ДН. ВМЕСТЕ',
          style: type.labelSmall?.copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 5),
        Text(
          today.greeting,
          style: type.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(today.message, style: type.bodyMedium),
      ],
    );
    final goalLabel = Text(
      today.mood == TodayMood.complete
          ? 'Цель дня достигнута'
          : 'Твоя цель дня',
      style: type.titleMedium,
    );
    final goalValue = Text(
      '${today.xp} / ${today.goal} XP',
      key: const Key('today-xp'),
      style: type.titleMedium,
    );
    return pageBody([
      if (largeText) ...[
        Align(alignment: Alignment.centerLeft, child: companion),
        greeting,
      ] else
        Row(
          children: [
            Expanded(child: greeting),
            companion,
          ],
        ),
      const SizedBox(height: 16),
      FlightPanel(
        accent: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (largeText)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [goalLabel, goalValue],
              )
            else
              Row(
                children: [
                  Expanded(child: goalLabel),
                  goalValue,
                ],
              ),
            const SizedBox(height: 10),
            FlightProgress(
              value: today.xp,
              target: today.goal,
              label: 'Цель дня',
            ),
            const SizedBox(height: 14),
            Text('ДАЛЬШЕ · ${next.title}', style: type.labelLarge),
            if (app.repository.learningObjectives[next.id]?.isNotEmpty ==
                true) ...[
              const SizedBox(height: 6),
              Text(
                app.repository.learningObjectives[next.id]!,
                style: type.bodyMedium,
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('today-start'),
                onPressed: () {
                  unawaited(app.audio.play(SoundEffect.tap));
                  context.go(nextLessonRoute(app));
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Продолжить урок'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(child: Text('Три задания дня', style: type.titleMedium)),
          TextButton(
            onPressed: () => context.go('/quests'),
            child: const Text('Все детали'),
          ),
        ],
      ),
      FlightPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            for (final mission in DailyMission.all)
              MissionFlightRow(mission: mission),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (personalPractice(
        app.repository.vocabulary.values,
        app.progress,
        app.repository.now(),
      ).isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => context.go('/practice'),
          icon: const Icon(Icons.psychology_outlined),
          label: const Text('Перед полётом: короткая разминка'),
        ),
      InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.go(app.inventory.unopened > 0 ? '/rewards' : '/quests'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Image.asset(
                'assets/kvesmos/explorer_closed.png',
                width: 46,
                height: 42,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  app.inventory.unopened > 0
                      ? 'Твои находки ждут · ${app.inventory.unopened}'
                      : 'Первый сундук — за завершённый урок',
                  style: type.bodyMedium,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => context.go('/map'),
        icon: const Icon(Icons.route_rounded),
        label: const Text('Карта путешествия'),
      ),
      const SizedBox(height: 8),
      Text(
        'Твой темп. Твоя орбита. Без штрафов за паузы.',
        style: type.bodySmall,
        textAlign: TextAlign.center,
      ),
    ]);
  }
}

class MissionFlightRow extends ConsumerWidget {
  final DailyMission mission;
  const MissionFlightRow({super.key, required this.mission});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), state = app.missions!;
    final earned = state.awarded(mission);
    final locked =
        mission.id == 'review' &&
        !earned &&
        (app.progress.words.length < 5 || !reviewReadyToday(app));
    final count = state.progress.count(mission).clamp(0, mission.target);
    final title = switch (mission.id) {
      'lesson' => 'Один урок',
      'answers' => '10 верных ответов',
      _ => '5 знакомых слов',
    };
    final subtitle = earned
        ? 'Сундук уже твой'
        : locked
        ? app.progress.words.length < 5
              ? 'Откроется с 5 словами · сейчас ${app.progress.words.length}'
              : 'Новые слова закрепятся — вернёмся по расписанию'
        : mission.chest == 'nebula'
        ? 'Награда: сундук туманности'
        : 'Награда: сундук исследователя';
    return Semantics(
      button: true,
      label: '$title. $subtitle. $count из ${mission.target}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.go(
          earned
              ? '/rewards'
              : locked
              ? nextLessonRoute(app)
              : mission.id == 'review'
              ? '/review'
              : nextLessonRoute(app),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(
                earned
                    ? Icons.check_circle_rounded
                    : locked
                    ? Icons.lock_outline_rounded
                    : mission.id == 'review'
                    ? Icons.refresh_rounded
                    : Icons.auto_awesome_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.labelLarge),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count/${mission.target}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
