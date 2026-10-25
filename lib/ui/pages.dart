import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/controller.dart';
import '../domain/course.dart';
import '../domain/progress.dart';
import '../domain/learning_recap.dart';
import '../domain/missions.dart';
import '../services/device.dart';
import 'design.dart';
import 'character_reactions.dart';
import 'weekly_activity.dart';
import 'rewards_pages.dart';
import 'adventure_map.dart';
import 'profile_achievements.dart';
import 'audio_settings.dart';
import 'galaxy_components.dart';
import '../services/learning_audio.dart';

class OnboardingPage extends ConsumerWidget {
  final int step;
  const OnboardingPage({super.key, required this.step});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('KVESMOS'),
        leading: step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    context.go(['/welcome', '/language', '/level'][step - 1]),
              )
            : null,
      ),
      body: pageBody([
        Center(
          child: step == 0
              ? const OrbitRobot(size: 180)
              : CharacterReaction(
                  cue: CharacterCue.navigator,
                  eventKey: 'onboarding-$step',
                  announce: false,
                ),
        ),
        Text(
          [
            'Ваш следующий мир начинается со слова.',
            'Куда отправимся?',
            'Выберите точку старта',
            'Небольшая цель. Большие открытия.',
          ][step],
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        Text(
          [
            'Я Орби, ваш спутник в изучении языков. Здесь можно ошибаться, пробовать снова и учиться в своём темпе. Всё бесплатно — всегда.',
            'Первый маршрут: английский для русскоговорящих. 20 коротких уроков и 60 слов.',
            'Этот курс знакомит с основами A1. Выбор помогает настроить приветствие; это не тест уровня.',
            'Цель мотивирует, но никогда не ограничивает число уроков. Её можно изменить в настройках.',
          ][step],
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (step == 0)
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Без подписки')),
              Chip(label: Text('Без рекламы')),
              Chip(label: Text('Без лимита ошибок')),
            ],
          ),
        if (step == 1) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.public, color: violet, size: 36),
              title: const Text('Английский'),
              subtitle: const Text('Русский → English · основы A1'),
              trailing: const Icon(
                Icons.check_circle,
                color: Color(0xFF007B73),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Другие языки появятся после подготовки и проверки курсов.',
          ),
        ],
        if (step == 2)
          ...['С нуля', 'Знаю немного'].map(
            (level) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(level),
                ),
                selected: app.startingLevel == level,
                onSelected: (_) => app.savePreferences(level: level),
              ),
            ),
          ),
        if (step == 3)
          ...[25, 50, 100].map(
            (goal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('$goal XP в день'),
                ),
                selected: app.goal == goal,
                onSelected: (_) => app.savePreferences(newGoal: goal),
              ),
            ),
          ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () async {
            if (step == 3) {
              await app.finishOnboarding();
              if (context.mounted) context.go('/');
            } else {
              context.go(['/language', '/level', '/goal'][step]);
            }
          },
          child: Text(step == 3 ? 'Начать путешествие' : 'Продолжить'),
        ),
        const SizedBox(height: 18),
        Text(
          'ШАГ ${step + 1} ИЗ 4',
          textAlign: TextAlign.center,
          style: const TextStyle(letterSpacing: 2, fontSize: 12),
        ),
      ]),
    );
  }
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), p = app.progress;
    final catalog = app.repository.catalog;
    final next =
        catalog.where((e) => !p.completed.contains(e.id)).firstOrNull ??
        catalog.first;
    final today = p.dailyXp[dayKey(DateTime.now())] ?? 0;
    return pageBody([
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Привет, ${app.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.bolt, color: coral),
            Text(
              '${p.xp} XP',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      SpaceBanner(
        animate: app.audio.preferences.reactions,
        eyebrow: 'ЭКСПЕДИЦИЯ A1 · ${p.completed.length} / ${catalog.length}',
        title: next.title,
        subtitle:
            app.repository.learningObjectives[next.id] ??
            'Следующая миссия твоей экспедиции.',
        action: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: turquoise,
            foregroundColor: space,
          ),
          onPressed: () => context.go(
            app.installed.contains(next.id) ? '/lesson/${next.id}' : '/offline',
          ),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Продолжить урок'),
        ),
      ),
      const SizedBox(height: 16),
      JourneyConstellation(
        lessons: catalog,
        completed: p.completed,
        onOpen: (lesson) {
          final unlocked =
              lesson.order == 0 ||
              p.completed.contains(lesson.id) ||
              p.completed.contains(catalog[lesson.order - 1].id);
          if (unlocked) {
            context.go(
              app.installed.contains(lesson.id)
                  ? '/lesson/${lesson.id}'
                  : '/offline',
            );
          } else {
            showMessage(
              context,
              'Сначала заверши предыдущую миссию. Каждая готовит к следующей.',
            );
          }
        },
      ),
      const SizedBox(height: 12),
      Card(
        child: CharacterReaction(
          cue: hasDailyXpRecord(p, DateTime.now())
              ? CharacterCue.record(today)
              : CharacterCue.greeting,
          eventKey:
              'home:${dayKey(DateTime.now())}:${hasDailyXpRecord(p, DateTime.now()) ? today : 0}',
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.track_changes, color: violet),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      today >= app.goal
                          ? 'Дневная цель достигнута!'
                          : 'Ваша цель на сегодня',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      '$today / ${app.goal} XP',
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: (today / app.goal).clamp(0, 1),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                today >= app.goal
                    ? 'Отличная работа. Если хочется — продолжайте!'
                    : 'Каждый верный ответ добавляет 10 XP. Ошибки ничего не отнимают.',
              ),
            ],
          ),
        ),
      ),
      Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => context.go('/quests'),
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Задания дня'),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: () => context.go('/review'),
              icon: const Icon(Icons.refresh),
              label: const Text('Повторение'),
            ),
          ),
        ],
      ),
      const RewardShortcut(),
      const AdventureMap(),
      const SizedBox(height: 24),
      Text(
        app.sync?.status ?? 'Локальный режим · уроки и прогресс на устройстве',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ]);
  }
}

class WordsPage extends ConsumerStatefulWidget {
  const WordsPage({super.key});
  @override
  ConsumerState<WordsPage> createState() => _WordsPageState();
}

class _WordsPageState extends ConsumerState<WordsPage> {
  String query = '';
  late final LearningAudio voice;
  @override
  void initState() {
    super.initState();
    voice = ref.read(appProvider).audio;
  }

  @override
  void dispose() {
    unawaited(voice.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final words = app.repository.vocabulary.values
        .where(
          (w) =>
              app.progress.words.containsKey(w.id) &&
              '${w.en} ${w.ru}'.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return pageBody([
      MissionHeader(
        eyebrow: 'Бортовой журнал',
        title: 'Ваш словарь',
        icon: Icons.auto_stories_rounded,
        subtitle:
            '${app.progress.words.length} слов открыто. Повторение помогает сохранить их в памяти.',
      ),
      const CharacterReaction(
        cue: CharacterCue.words,
        eventKey: 'vocabulary',
        announce: false,
      ),
      TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Найти слово',
        ),
        onChanged: (v) => setState(() => query = v),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => context.go('/review'),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Повторить слова'),
      ),
      const SizedBox(height: 20),
      if (words.isEmpty)
        const Text(
          'Пока ничего не найдено. Пройдите урок, чтобы пополнить словарь.',
        ),
      ...words.map((w) {
        final state = app.progress.words[w.id]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              title: Text(w.en, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(
                '${w.ru}\n${(state.mastery * 100).round()}% освоено · повтор ${dayKey(state.next!.toLocal())}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Произнести ${w.en}',
                icon: const Icon(Icons.volume_up_outlined),
                onPressed: () async {
                  if (!await voice.speak(w.en, character: 'aster') &&
                      context.mounted) {
                    showMessage(
                      context,
                      'Английский голос недоступен. Установите его в настройках речи устройства.',
                    );
                  }
                },
              ),
            ),
          ),
        );
      }),
    ]);
  }
}

class ReviewPage extends ConsumerStatefulWidget {
  final bool mistakesOnly;
  const ReviewPage({super.key, this.mistakesOnly = false});
  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  final input = TextEditingController();
  List<Vocabulary>? queue;
  int index = 0;
  bool? correct;
  bool busy = false;
  Map<String, Exercise> examples = {};
  @override
  void initState() {
    super.initState();
    unawaited(loadExamples());
  }

  Future<void> loadExamples() async {
    try {
      final loaded = await ref.read(appProvider).repository.mistakeExamples();
      if (mounted) setState(() => examples = loaded);
    } catch (_) {
      /* Word review remains available if an old example cannot load. */
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    queue ??= reviewWords(
      app.repository.vocabulary.values,
      app.progress,
      DateTime.now(),
      mistakesOnly: widget.mistakesOnly,
    );
    final finished = index >= queue!.length;
    return pageBody([
      const MissionHeader(
        eyebrow: 'Тренировка памяти',
        title: 'Сигналы памяти',
        icon: Icons.psychology_rounded,
        subtitle:
            'Сначала слова, которым пора вернуться. Ошибки помогают подобрать следующий интервал.',
      ),
      if (widget.mistakesOnly)
        const Text(
          'Добровольная тренировка ошибок. Плановые интервалы повторения сохраняются.',
        ),
      if (finished) ...[
        CharacterReaction(
          cue: CharacterCue('reyvo', 'Рэйво', [
            queue!.isEmpty
                ? 'На сегодня повторений нет. Можно отдохнуть или потренироваться по желанию.'
                : 'Отличная разминка! Все запланированные слова повторены.',
            'Знакомые слова становятся увереннее с каждой встречей.',
          ]),
          eventKey: 'review-finished:${queue!.length}',
        ),
        Text(
          queue!.isEmpty
              ? 'На сегодня повторений нет.'
              : 'Все запланированные слова повторены!',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('К урокам'),
        ),
        if (reviewWords(
          app.repository.vocabulary.values,
          app.progress,
          DateTime.now(),
          mistakesOnly: true,
        ).isNotEmpty)
          TextButton(
            onPressed: () => setState(() {
              queue = reviewWords(
                app.repository.vocabulary.values,
                app.progress,
                DateTime.now(),
                mistakesOnly: true,
              );
              index = 0;
              correct = null;
              input.clear();
            }),
            child: const Text('Практиковать сложные слова сейчас'),
          ),
      ] else ...[
        CharacterReaction(
          cue: CharacterCue.practice,
          eventKey: 'review-$index',
          announce: false,
        ),
        Text('${index + 1} / ${queue!.length}'),
        const SizedBox(height: 18),
        Text(
          queue![index].ru,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: input,
          enabled: correct == null,
          decoration: const InputDecoration(hintText: 'Напишите по-английски'),
        ),
        const SizedBox(height: 20),
        if (correct != null)
          Text(
            correct!
                ? 'Верно! +10 XP'
                : '${queue![index].en} — ${queue![index].ru}. Слово вернётся завтра.',
          ),
        if (correct == false)
          if (examples[queue![index].id] case final example?)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Вспомни ситуацию из урока'),
                    Text(example.prompt),
                    Text(example.explanation),
                  ],
                ),
              ),
            ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (correct != null) {
                    setState(() {
                      index++;
                      correct = null;
                      input.clear();
                    });
                    return;
                  }
                  if (input.text.trim().isEmpty) return;
                  setState(() => busy = true);
                  try {
                    final word = queue![index];
                    await app.repository.review(word, input.text);
                    await app.refresh();
                    if (mounted) {
                      setState(
                        () => correct =
                            normalizeAnswer(input.text) ==
                            normalizeAnswer(word.en),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      showMessage(
                        context,
                        'Не удалось сохранить ответ. Попробуйте снова.',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(correct == null ? 'Проверить' : 'Дальше'),
        ),
      ],
    ]);
  }
}

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), p = app.progress;
    final total = p.correct + p.errors;
    return pageBody([
      const SectionTitle(
        'Ваш путь к звёздам',
        subtitle: 'Реальные результаты каждого маленького шага.',
      ),
      const ExpansionTile(
        title: Text('Совет профессора'),
        children: [
          CharacterReaction(
            cue: CharacterCue.scholar,
            eventKey: 'stats',
            announce: false,
          ),
        ],
      ),
      LayoutBuilder(
        builder: (context, c) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Metric(
              value: '${p.xp}',
              label: 'опыта XP',
              icon: Icons.auto_awesome,
              color: coral,
            ),
            Metric(
              value: '${p.streak(DateTime.now())}',
              label: 'дней подряд',
              icon: Icons.local_fire_department_outlined,
              color: coral,
            ),
            Metric(
              value: '${p.completed.length} / ${app.repository.catalog.length}',
              label: 'уроков освоено',
              icon: Icons.public,
            ),
            Metric(
              value: '${p.words.length}',
              label: 'слов в словаре',
              icon: Icons.style_outlined,
            ),
          ].map((w) => SizedBox(width: (c.maxWidth - 12) / 2, child: w)).toList(),
        ),
      ),
      SectionTitle(
        'Уровень ${p.level}',
        subtitle: 'Следующий уровень через ${250 - p.xp % 250} XP',
      ),
      LinearProgressIndicator(value: (p.xp % 250) / 250, minHeight: 8),
      SectionTitle(
        'Точность ${total == 0 ? '—' : '${(100 * p.correct / total).round()}%'}',
        subtitle:
            'Верных ответов: ${p.correct}. Ошибок: ${p.errors}. Все попытки учитываются.',
      ),
      const SectionTitle('Последние 7 дней'),
      WeeklyActivity(app),
      const SizedBox(height: 16),
      ...List.generate(7, (i) {
        final day = DateTime.now().subtract(Duration(days: 6 - i));
        final xp = p.dailyXp[dayKey(day)] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(width: 96, child: Text(dayKey(day))),
              Expanded(
                child: LinearProgressIndicator(
                  value: (xp / app.goal).clamp(0, 1),
                  minHeight: 10,
                ),
              ),
              SizedBox(
                width: 65,
                child: Text('$xp XP', textAlign: TextAlign.end),
              ),
            ],
          ),
        );
      }),
      const SectionTitle('Разделы курса'),
      ...app.repository.catalog.map((e) => e.section).toSet().map((section) {
        final lessons = app.repository.catalog
            .where((e) => e.section == section)
            .toList();
        final done = lessons.where((e) => p.completed.contains(e.id)).length;
        return ListTile(
          title: Text(section),
          subtitle: LinearProgressIndicator(value: done / lessons.length),
          trailing: Text('$done / ${lessons.length}'),
        );
      }),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => context.go('/achievements'),
        icon: const Icon(Icons.workspace_premium_outlined),
        label: const Text('Достижения'),
      ),
      TextButton(
        onPressed: () => context.go('/quests'),
        child: const Text('Ежедневные задания'),
      ),
    ]);
  }
}

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(appProvider).progress.achievements;
    const goals = {
      'Первый контакт': 'Завершите первый урок',
      'Исследователь': 'Пройдите 5 разных уроков',
      'Новая планета': 'Пройдите 10 разных уроков',
      'Созвездие A1': 'Пройдите все 20 уроков',
      'Хранитель слов': 'Откройте 30 слов',
      'Тысяча звёзд': 'Накопите 1000 XP',
    };
    return pageBody([
      const SpaceBanner(
        eyebrow: 'КОЛЛЕКЦИЯ ОТКРЫТИЙ',
        title: 'У каждого шага\nсвоя звезда.',
        subtitle: 'Награды остаются с вами. Ошибки их не отнимают.',
      ),
      ...goals.entries.map(
        (e) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: Icon(
                unlocked.contains(e.key)
                    ? Icons.auto_awesome
                    : Icons.star_outline,
                color: unlocked.contains(e.key) ? coral : Colors.grey,
                size: 36,
              ),
              title: Text(e.key),
              subtitle: Text(e.value),
              trailing: unlocked.contains(e.key)
                  ? const Icon(Icons.check_circle, color: Color(0xFF007B73))
                  : null,
            ),
          ),
        ),
      ),
    ]);
  }
}

class QuestsPage extends ConsumerWidget {
  const QuestsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), state = app.missions;
    if (state == null) return const Center(child: CircularProgressIndicator());
    return pageBody([
      const SectionTitle(
        'Задания дня',
        subtitle:
            'Маленькая практика — новые находки. Все три задания бесплатны.',
      ),
      Text(
        'Сегодня: ${state.day}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'Обновление в 00:00 по времени устройства. Награды выдаются автоматически и остаются у вас.',
      ),
      const SizedBox(height: 20),
      for (final mission in DailyMission.all)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(mission.description),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: (state.progress.count(mission) / mission.target)
                        .clamp(0, 1),
                    minHeight: 8,
                    semanticsLabel:
                        '${mission.title}: ${state.progress.count(mission).clamp(0, mission.target)} из ${mission.target}',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state.awarded(mission)
                        ? 'Выполнено · сундук получен'
                        : '${state.progress.count(mission).clamp(0, mission.target)} / ${mission.target}',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Image.asset(
                        'assets/kvesmos/${mission.chest}_closed.png',
                        width: 64,
                        height: 56,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Награда: ${app.rewards.catalog.chest(mission.chest)['name_ru']}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.go(
                      state.awarded(mission)
                          ? '/rewards'
                          : mission.id == 'review'
                          ? '/review'
                          : '/',
                    ),
                    icon: Icon(
                      state.awarded(mission)
                          ? Icons.redeem_rounded
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      state.awarded(mission)
                          ? 'К сундукам'
                          : mission.id == 'review'
                          ? 'Повторить слова'
                          : 'К урокам',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      const Text(
        'Одно задание — одна награда за календарный день. Можно выполнить любое из трёх; пропуски ничего не отнимают.',
      ),
    ]);
  }
}

class OfflinePage extends ConsumerStatefulWidget {
  const OfflinePage({super.key});
  @override
  ConsumerState<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends ConsumerState<OfflinePage> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    return pageBody([
      const SectionTitle(
        'Обучение без сети',
        subtitle:
            'Курс включён в приложение. Сохранение переносит урок в локальную SQLite-базу и не требует интернета.',
      ),
      Text('${app.installed.length} из 20 уроков сохранено'),
      const SizedBox(height: 12),
      const Text(
        'Озвучивание требует установленного английского голоса. Распознавание речи зависит от устройства; ввод текста доступен всегда.',
      ),
      const SizedBox(height: 20),
      ...app.repository.catalog.map(
        (lesson) => Card(
          child: ListTile(
            title: Text(lesson.title),
            subtitle: Text(
              app.installed.contains(lesson.id)
                  ? 'Доступен офлайн'
                  : 'Можно восстановить из приложения',
            ),
            trailing: IconButton(
              tooltip: app.installed.contains(lesson.id)
                  ? 'Удалить локальную копию'
                  : 'Сохранить урок',
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        if (app.installed.contains(lesson.id)) {
                          await app.repository.uninstall(lesson.id);
                        } else {
                          await app.repository.install(lesson);
                        }
                        await app.refresh();
                      } catch (_) {
                        if (context.mounted) {
                          showMessage(
                            context,
                            'Операция не выполнена. Проверьте свободное место.',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              icon: Icon(
                app.installed.contains(lesson.id)
                    ? Icons.delete_outline
                    : Icons.download_outlined,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> act(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Операция не выполнена. Проверьте сеть и повторите.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider),
        cloud = app.cloud,
        user = app.cloud?.auth.currentUser;
    return pageBody([
      MissionHeader(
        eyebrow: 'Паспорт исследователя',
        title: 'Мой профиль',
        subtitle:
            'Уровень ${app.progress.level} · ${app.progress.completed.length} миссий · ${app.inventory.owned.length} находок',
        icon: Icons.badge_outlined,
      ),
      ProfileLook(app),
      const SizedBox(height: 16),
      const AchievementShowcase(),
      const SizedBox(height: 16),
      const RewardShortcut(),
      TextButton.icon(
        onPressed: () => context.go('/crew'),
        icon: const Icon(Icons.groups_outlined),
        label: const Text('Команда KVESMOS'),
      ),
      const SectionTitle('Сохранение прогресса'),
      if (cloud == null) ...[
        const Text(
          'Ваш прогресс и коллекция сохранены на этом устройстве. Все уроки доступны без аккаунта. Облачная синхронизация пока не подключена.',
        ),
        if (app.cloudError != null) Text(app.cloudError!),
      ] else if (user == null) ...[
        const Text(
          'При первом входе локальный прогресс будет перенесён в аккаунт. На общем устройстве сначала удалите данные предыдущего пользователя в настройках.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Электронная почта'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(
            labelText: 'Пароль (не менее 8 символов)',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy
              ? null
              : () => act(() async {
                  await cloud.auth.signInWithPassword(
                    email: email.text.trim(),
                    password: password.text,
                  );
                  password.clear();
                  await app.synchronize();
                }),
          child: const Text('Войти'),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => act(() async {
                  if (password.text.length < 8) {
                    showMessage(context, 'Введите пароль не менее 8 символов.');
                    return;
                  }
                  await cloud.auth.signUp(
                    email: email.text.trim(),
                    password: password.text,
                  );
                  password.clear();
                  if (context.mounted) {
                    showMessage(
                      context,
                      'Если требуется подтверждение, откройте письмо и затем войдите.',
                    );
                  }
                }),
          child: const Text('Создать бесплатный аккаунт'),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => act(() async {
                  await cloud.auth.resetPasswordForEmail(
                    email.text.trim(),
                    redirectTo: 'dev.orbitwords://auth-callback',
                  );
                  if (context.mounted) {
                    showMessage(
                      context,
                      'Проверьте почту: отправлена ссылка восстановления.',
                    );
                  }
                }),
          child: const Text('Забыли пароль?'),
        ),
      ] else ...[
        if (app.recoveringPassword) ...[
          const SectionTitle('Новый пароль'),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Не менее 8 символов'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy
                ? null
                : () => act(() async {
                    if (password.text.length < 8) {
                      showMessage(context, 'Введите не менее 8 символов.');
                      return;
                    }
                    await cloud.auth.updateUser(
                      UserAttributes(password: password.text),
                    );
                    password.clear();
                    app.recoveringPassword = false;
                    await app.refresh();
                    if (context.mounted) {
                      showMessage(context, 'Пароль изменён.');
                    }
                  }),
            child: const Text('Изменить пароль'),
          ),
          const SizedBox(height: 20),
        ],
        Text(user.email ?? 'Аккаунт подключён'),
        const SizedBox(height: 12),
        Text(app.sync?.status ?? ''),
        if (app.cloudError != null)
          Text(
            app.cloudError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy || app.sync?.busy == true
              ? null
              : () => act(app.synchronize),
          icon: const Icon(Icons.sync),
          label: const Text('Синхронизировать'),
        ),
        TextButton(
          onPressed: busy || app.sync?.busy == true
              ? null
              : () => act(() async {
                  await app.changeAccount(
                    () => cloud.auth.signOut(scope: SignOutScope.local),
                  );
                  await app.refresh();
                }),
          child: const Text('Выйти на этом устройстве'),
        ),
        const SectionTitle('Удаление аккаунта'),
        const Text(
          'Удаляет аккаунт, облачную историю и локальный прогресс. Отменить это действие нельзя.',
        ),
        OutlinedButton(
          onPressed: busy || app.sync?.busy == true
              ? null
              : () async {
                  if (!await confirmDelete(
                    context,
                    'Удалить аккаунт и весь прогресс?',
                  )) {
                    return;
                  }
                  await act(() async {
                    await app.changeAccount(() async {
                      await cloud.functions.invoke('delete-account');
                      try {
                        await cloud.auth.signOut(scope: SignOutScope.local);
                      } finally {
                        await app.repository.reset();
                        await app.initializeAfterReset();
                      }
                    });
                    if (context.mounted) context.go('/welcome');
                  });
                },
          child: const Text('Удалить аккаунт и данные'),
        ),
      ],
      const SizedBox(height: 20),
      TextButton(
        onPressed: () => context.go('/settings'),
        child: const Text('Настройки профиля'),
      ),
    ]);
  }
}

Future<bool> confirmDelete(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    ) ??
    false;

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  TextEditingController? name;
  bool reminders = false, busy = false;
  final reminderService = ReminderService();
  @override
  void initState() {
    super.initState();
    ref.read(appProvider).repository.setting('reminders').then((v) {
      if (mounted) setState(() => reminders = v == 'true');
    });
  }

  @override
  void dispose() {
    name?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    name ??= TextEditingController(text: app.name);
    return pageBody([
      const SectionTitle('Настройки'),
      const AudioSettings(),
      TextField(
        controller: name,
        maxLength: 40,
        decoration: const InputDecoration(labelText: 'Как вас называть?'),
      ),
      FilledButton(
        onPressed: () async {
          await app.savePreferences(newName: name!.text);
          if (context.mounted) showMessage(context, 'Имя сохранено.');
        },
        child: const Text('Сохранить имя'),
      ),
      const SectionTitle('Ежедневная цель'),
      Wrap(
        spacing: 12,
        children: [25, 50, 100]
            .map(
              (g) => ChoiceChip(
                label: Text('$g XP'),
                selected: app.goal == g,
                onSelected: (_) => app.savePreferences(newGoal: g),
              ),
            )
            .toList(),
      ),
      const SectionTitle('Оформление'),
      Wrap(
        spacing: 12,
        children: ThemeMode.values
            .map(
              (t) => ChoiceChip(
                label: Text(
                  {
                    'system': 'Как в системе',
                    'light': 'Светлое',
                    'dark': 'Тёмное',
                  }[t.name]!,
                ),
                selected: app.theme == t,
                onSelected: (_) => app.savePreferences(newTheme: t),
              ),
            )
            .toList(),
      ),
      const SectionTitle('Напоминания'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Раз в сутки с момента включения'),
        subtitle: const Text(
          'Приблизительное время. Разрешение запрашивается только при включении.',
        ),
        value: reminders,
        onChanged: busy
            ? null
            : (v) async {
                setState(() => busy = true);
                try {
                  if (v) {
                    final ok = await reminderService.enable();
                    if (!ok) {
                      if (context.mounted) {
                        showMessage(context, 'Уведомления не разрешены.');
                      }
                      return;
                    }
                  } else {
                    await reminderService.disable();
                  }
                  await app.repository.setSetting('reminders', '$v');
                  if (mounted) setState(() => reminders = v);
                } catch (_) {
                  if (context.mounted) {
                    showMessage(
                      context,
                      'Не удалось настроить уведомления на этом устройстве.',
                    );
                  }
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
      ),
      const SectionTitle('Доступность'),
      const Text(
        'Размер текста следует настройке устройства. При отключении системных анимаций эффекты сокращаются. Микрофон необязателен; для речи есть текстовый режим.',
      ),
      const SectionTitle('Конфиденциальность'),
      const Text(
        'Без рекламы и аналитических SDK. Локально сохраняются ответы, XP и настройки. При включении синхронизации история обучения и email хранятся в Supabase. Аудиозаписи приложение не сохраняет. Системные голосовые службы могут обрабатывать речь по правилам вашей ОС.',
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: busy || app.sync?.busy == true
            ? null
            : () async {
                if (!await confirmDelete(
                  context,
                  'Очистить данные на этом устройстве?',
                )) {
                  return;
                }
                setState(() => busy = true);
                try {
                  await app.changeAccount(() async {
                    await app.cloud?.auth.signOut(scope: SignOutScope.local);
                    await reminderService.disable();
                    await app.repository.reset();
                    await app.initializeAfterReset();
                  });
                  if (context.mounted) context.go('/welcome');
                } catch (_) {
                  if (context.mounted) {
                    showMessage(
                      context,
                      'Не удалось очистить данные. Попробуйте снова.',
                    );
                  }
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        child: const Text('Удалить локальные данные'),
      ),
      const SizedBox(height: 8),
      const Text(
        'Облачные данные при локальной очистке сохраняются. Удаление аккаунта доступно в профиле.',
      ),
      const SectionTitle('KVESMOS · Галактика знаний'),
      const Text(
        'Оригинальный бесплатный курс. Рабочее название подлежит проверке перед публикацией.',
      ),
    ]);
  }
}
