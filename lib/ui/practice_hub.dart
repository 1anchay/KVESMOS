import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/practice_repository.dart';
import '../data/smart_practice_repository.dart';
import 'design.dart';
import 'flight_components.dart';
import 'character_moment.dart';
import 'today_page.dart';
import '../domain/study_skills.dart';

const practiceLabels = {
  PracticeMode.words: (
    'Слова',
    'Вспоминай значения знакомых слов и фраз.',
    Icons.style_outlined,
  ),
  PracticeMode.listen: (
    'Аудирование',
    'Поймай сигнал на слух. При необходимости открой текст.',
    Icons.headphones_outlined,
  ),
  PracticeMode.speak: (
    'Говорение',
    'Произнеси фразу или введи ответ вручную.',
    Icons.mic_none,
  ),
  PracticeMode.mistakes: (
    'Ошибки',
    'Разбери материал, который пока вызывает трудности.',
    Icons.build_outlined,
  ),
  PracticeMode.dialogue: (
    'Диалоги',
    'Восстанови реплики из пройденных разговоров.',
    Icons.forum_outlined,
  ),
  PracticeMode.warmup: (
    'Разминка',
    'Три слова, которым пора вернуться по расписанию.',
    Icons.bolt_outlined,
  ),
};

class PracticeHub extends ConsumerStatefulWidget {
  const PracticeHub({super.key});
  @override
  ConsumerState<PracticeHub> createState() => _PracticeHubState();
}

class _PracticeHubState extends ConsumerState<PracticeHub> {
  Object? progress;
  String? courseId;
  Future<(SmartPlan, bool)>? recommendation;

  Future<(SmartPlan, bool)> _recommend(
    SmartPracticeRepository repository,
  ) async => (await repository.plan(), await repository.hasDraft());

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final theme = Theme.of(context).textTheme;
    if (!identical(progress, app.progress) || courseId != app.course.id) {
      progress = app.progress;
      courseId = app.course.id;
      recommendation = _recommend(SmartPracticeRepository(app.repository));
    }
    return pageBody([
      const CharacterMoment(characterId: 'miko', size: 80, animate: false),
      Text('Тренировочная орбита', style: theme.headlineMedium),
      Text('${app.course.name} · выбери, что хочется закрепить'),
      const SizedBox(height: 12),
      Text(
        app.progress.words.isEmpty
            ? 'После первого занятия здесь появится знакомый материал.'
            : 'Знакомых слов и фраз: ${app.progress.words.length}. Сначала возвращаем те, которым нужно внимание.',
      ),
      const SizedBox(height: 16),
      FutureBuilder<(SmartPlan, bool)>(
        future: recommendation,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          final plan = snapshot.data?.$1;
          final resumable = snapshot.data?.$2 ?? false;
          final skill = plan?.skill;
          return FlightPanel(
            accent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Сегодня потренировать', style: theme.titleLarge),
                if (skill != null) Text(skill.label, style: theme.titleMedium),
                const SizedBox(height: 8),
                Text('Почему рекомендовано', style: theme.labelLarge),
                Text(
                  plan?.reason ??
                      'Можно продолжить урок или выбрать знакомый режим.',
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => context.go(
                    resumable
                        ? '/smart-practice'
                        : switch (plan?.listeningScene) {
                            final scene? => '/listening/$scene?repeat=1',
                            null =>
                              skill == null
                                  ? nextLessonRoute(app)
                                  : '/smart-practice',
                          },
                  ),
                  icon: const Icon(Icons.bolt_outlined),
                  label: Text(
                    resumable
                        ? 'Продолжить личную тренировку'
                        : plan?.listeningScene != null
                        ? 'Повторить аудиодиалог'
                        : skill == null
                        ? 'К следующему уроку'
                        : 'Начать тренировку · ${plan!.items.length < 4 ? 'короткая подборка' : '3–5 минут'}',
                  ),
                ),
                if (plan != null)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Ответы по навыкам за 30 дней'),
                    children: [
                      for (final skill in StudySkill.values)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(skill.label),
                          subtitle: Text(
                            plan.report.evidence[skill]!.attempts == 0
                                ? 'Пока нет подтверждённых ответов'
                                : 'Верно: ${plan.report.evidence[skill]!.correct} · '
                                      'С ошибкой: ${plan.report.evidence[skill]!.errors}',
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
      for (final entry in practiceLabels.entries) ...[
        const SizedBox(height: 12),
        FlightPanel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(entry.value.$3),
            title: Text(entry.value.$1),
            subtitle: Text(entry.value.$2),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/practice/${entry.key.name}'),
          ),
        ),
        if (entry.key == PracticeMode.words)
          OutlinedButton.icon(
            onPressed: () => context.go('/pictures'),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Слова по картинкам'),
          ),
        if (entry.key == PracticeMode.listen)
          OutlinedButton.icon(
            onPressed: () => context.go('/listening'),
            icon: const Icon(Icons.headphones_outlined),
            label: const Text('Короткие аудиодиалоги'),
          ),
        if (entry.key == PracticeMode.dialogue)
          OutlinedButton.icon(
            onPressed: () => context.go('/conversations'),
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Разговоры с экипажем'),
          ),
      ],
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => context.go('/words'),
        icon: const Icon(Icons.menu_book_outlined),
        label: const Text('Мой словарь и сроки повторения'),
      ),
    ]);
  }
}
