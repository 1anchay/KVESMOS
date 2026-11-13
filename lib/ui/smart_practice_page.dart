import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/controller.dart';
import '../data/smart_practice_repository.dart';
import '../domain/course.dart';
import '../domain/mistake_feedback.dart';
import '../domain/study_skills.dart';
import '../services/learning_audio.dart';
import 'character_moment.dart';
import 'design.dart';
import 'flight_components.dart';
import 'lesson_effects.dart';

class SmartPracticePage extends ConsumerStatefulWidget {
  const SmartPracticePage({super.key});
  @override
  ConsumerState<SmartPracticePage> createState() => _SmartPracticePageState();
}

class _SmartPracticePageState extends ConsumerState<SmartPracticePage> {
  late final app = ref.read(appProvider);
  late final repository = SmartPracticeRepository(app.repository);
  late final audio = app.audio;
  final input = TextEditingController();
  List<int> order = [];
  List<SmartItem> items = [];
  Map<String, dynamic>? state;
  SmartPlan? recap;
  bool loading = true, busy = false, failed = false;
  bool heard = false, reading = false, playing = false;
  String? soundProblem;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool restart = false}) async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final value = await repository.open(restart: restart);
      final material = value == null
          ? <SmartItem>[]
          : await repository.material(value);
      final plan = value == null || value['index'] == material.length
          ? await repository.plan()
          : null;
      if (!mounted) return;
      setState(() {
        state = value;
        items = material;
        input.text = value?['text'] as String? ?? '';
        order = List<int>.from(value?['order'] ?? []);
        recap = plan;
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _draft() async {
    try {
      await repository.draft(
        state!['run'],
        state!['index'],
        input.text,
        List.of(order),
      );
    } catch (_) {
      if (mounted) showMessage(context, 'Не удалось сохранить черновик.');
    }
  }

  Future<void> _play(Exercise exercise, bool slow) async {
    setState(() {
      playing = true;
      soundProblem = null;
    });
    final ok = await audio.speakThrough(
      exercise.audio!,
      character: exercise.character,
      locale: app.course.locale,
      slow: slow,
    );
    if (!mounted) return;
    setState(() {
      playing = false;
      heard = heard || ok;
      if (!ok) soundProblem = audio.lastProblem ?? 'Звук прервался.';
    });
  }

  Future<void> _submit(SmartItem item, String answer) async {
    if (busy || answer.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      final value = await repository.answer(
        state!['run'],
        state!['index'],
        item,
        answer,
        heard: heard && !reading,
      );
      if (!mounted) return;
      setState(() => state = value);
      unawaited(
        audio.play(
          value['correct'] == true
              ? SoundEffect.correct
              : SoundEffect.incorrect,
        ),
      );
      await app.refresh();
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Ответ не сохранился. Попробуй ещё раз.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _next() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final value = await repository.advance(state!['run'], state!['index']);
      final report = value['index'] == items.length
          ? await repository.plan()
          : null;
      if (!mounted) return;
      setState(() {
        state = value;
        input.clear();
        order = [];
        heard = false;
        reading = false;
        soundProblem = null;
        recap = report;
      });
    } catch (_) {
      if (mounted) showMessage(context, 'Не удалось перейти дальше.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    input.dispose();
    unawaited(audio.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final value = state;
    final index = value?['index'] as int? ?? 0;
    final item = items.elementAtOrNull(index);
    final exercise = item?.exercise;
    final skill = StudySkill.values
        .where((s) => s.name == value?['skill'])
        .firstOrNull;
    final correct = value?['correct'] as bool?;
    final listening = exercise?.type == ExerciseType.listen;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Личная тренировка'),
        leading: IconButton(
          tooltip: 'Сохранить и выйти',
          onPressed: () => context.go('/training'),
          icon: const Icon(Icons.close),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : pageBody([
              CharacterMoment(
                characterId: 'orbi',
                size: 78,
                state: correct == true
                    ? CharacterState.correct
                    : correct == false
                    ? CharacterState.support
                    : CharacterState.thinking,
                animate: correct != null && audio.preferences.reactions,
              ),
              if (failed) ...[
                const Text(
                  'Не удалось открыть сохранённую тренировку. Проверь доступность уроков или подбери новую.',
                ),
                OutlinedButton(
                  onPressed: () => _load(restart: true),
                  child: const Text('Подобрать заново'),
                ),
              ] else if (value == null) ...[
                Text(
                  recap?.reason ??
                      'Сначала пройди несколько заданий обычного урока.',
                ),
                FilledButton(
                  onPressed: () => context.go('/training'),
                  child: const Text('К тренировкам'),
                ),
              ] else if (exercise == null) ...[
                Text('Тренировка завершена', style: type.headlineSmall),
                Text('Верных ответов: ${value['score']} из ${items.length}.'),
                if (skill != null && recap != null)
                  Text(
                    'Заданий с последней ошибкой по навыку «${skill.label}»: '
                    '${recap!.report.evidence[skill]!.unresolved}.',
                  ),
                if (recap != null)
                  FlightPanel(child: Text('Что дальше · ${recap!.reason}')),
                FilledButton(
                  onPressed: () => context.go('/training'),
                  child: const Text('К тренировкам'),
                ),
                OutlinedButton(
                  onPressed: () => _load(restart: true),
                  child: const Text('Новая подборка'),
                ),
              ] else ...[
                Text(skill!.label, style: type.headlineSmall),
                Text(value['reason']),
                const SizedBox(height: 12),
                LessonProgress(done: index, total: items.length),
                const SizedBox(height: 12),
                Text(exercise.prompt, style: type.titleLarge),
                if (listening && correct == null) ...[
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: playing
                            ? null
                            : () => _play(exercise, false),
                        icon: const Icon(Icons.volume_up),
                        label: const Text('Послушать'),
                      ),
                      TextButton(
                        onPressed: playing ? null : () => _play(exercise, true),
                        child: const Text('Медленно'),
                      ),
                      TextButton(
                        onPressed: playing
                            ? null
                            : () => setState(() => reading = true),
                        child: const Text('Открыть текст'),
                      ),
                    ],
                  ),
                  if (reading) Text('Режим чтения · ${exercise.audio}'),
                  if (soundProblem != null) Text(soundProblem!),
                ],
                if (correct == null && (!listening || heard || reading)) ...[
                  if (exercise.type == ExerciseType.order &&
                      exercise.tokens.isNotEmpty) ...[
                    Text(
                      order.isEmpty
                          ? 'Выбирай слова по порядку'
                          : order.map((i) => exercise.tokens[i]).join(' '),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final (i, word) in exercise.tokens.indexed)
                          OutlinedButton(
                            onPressed: busy || order.contains(i)
                                ? null
                                : () {
                                    setState(() => order.add(i));
                                    unawaited(_draft());
                                  },
                            child: Text(word),
                          ),
                      ],
                    ),
                    TextButton(
                      onPressed: busy || order.isEmpty
                          ? null
                          : () {
                              setState(() => order.removeLast());
                              unawaited(_draft());
                            },
                      child: const Text('Убрать последнее слово'),
                    ),
                    FilledButton(
                      onPressed: busy || order.isEmpty
                          ? null
                          : () => _submit(
                              item!,
                              order.map((i) => exercise.tokens[i]).join(' '),
                            ),
                      child: const Text('Проверить'),
                    ),
                  ] else if (exercise.options.isNotEmpty)
                    for (final option in exercise.options)
                      OutlinedButton(
                        onPressed: busy ? null : () => _submit(item!, option),
                        child: Text(option),
                      )
                  else ...[
                    TextField(
                      controller: input,
                      enabled: !busy,
                      maxLength: 400,
                      decoration: const InputDecoration(
                        labelText: 'Твой ответ',
                      ),
                      onChanged: (_) => unawaited(_draft()),
                    ),
                    FilledButton(
                      onPressed: busy ? null : () => _submit(item!, input.text),
                      child: const Text('Проверить'),
                    ),
                  ],
                ],
                if (correct != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: FlightPanel(
                      accent: true,
                      child: Text(
                        correct
                            ? 'Верно! ${exercise.explanation}'
                            : 'Ответ: ${exercise.answers.first}\n${mistakeExplanation(exercise, value['text'])}',
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: busy ? null : _next,
                    child: const Text('Дальше'),
                  ),
                ],
              ],
            ]),
    );
  }
}
