import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/practice_repository.dart';
import '../domain/course.dart';
import '../services/learning_audio.dart';
import 'character_moment.dart';
import 'design.dart';
import 'flight_components.dart';
import 'today_page.dart';

class PersonalPracticePage extends ConsumerStatefulWidget {
  const PersonalPracticePage({super.key});
  @override
  ConsumerState<PersonalPracticePage> createState() =>
      _PersonalPracticePageState();
}

class _PersonalPracticePageState extends ConsumerState<PersonalPracticePage> {
  late final PracticeRepository practice;
  late final LearningAudio audio;
  final input = TextEditingController();
  Map<String, dynamic>? state;
  Map<String, Exercise> examples = {};
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final app = ref.read(appProvider);
    practice = PracticeRepository(app.repository);
    audio = app.audio;
    load();
  }

  Future<void> load({bool restart = false}) async {
    try {
      final value = await practice.open(restart: restart);
      final context = await practice.learning.mistakeExamples();
      if (mounted) {
        setState(() {
          state = value;
          examples = context;
          input.text = value['text'] ?? '';
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Не удалось открыть практику. Попробуйте ещё раз.',
        );
      }
    }
  }

  @override
  void dispose() {
    unawaited(audio.stop());
    input.dispose();
    super.dispose();
  }

  Future<void> next() async {
    if (busy ||
        state == null ||
        state!['phase'] == 1 && input.text.trim().isEmpty) {
      return;
    }
    setState(() => busy = true);
    try {
      final oldPhase = state!['phase'] as int;
      final value = await practice.advance(
        state!['index'],
        oldPhase,
        input.text,
      );
      await ref.read(appProvider).refresh();
      if (mounted) {
        setState(() {
          state = value;
          input.text = value['phase'] == 2 ? value['text'] : '';
        });
        if (oldPhase == 1) {
          unawaited(
            audio.play(
              value['correct'] == true
                  ? SoundEffect.correct
                  : SoundEffect.incorrect,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Не удалось сохранить ответ. Повторите действие.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), type = Theme.of(context).textTheme;
    if (error != null) {
      return pageBody([
        Text(error!),
        TextButton(onPressed: load, child: const Text('Повторить')),
      ]);
    }
    if (state == null) return const Center(child: CircularProgressIndicator());
    final ids = List<String>.from(state!['words']),
        index = state!['index'] as int,
        phase = state!['phase'] as int;
    if (index >= ids.length) {
      return pageBody([
        CharacterMoment(
          characterId: 'miko',
          state: CharacterState.correct,
          animate: audio.preferences.reactions,
          size: 96,
        ),
        Text(
          ids.isEmpty ? 'Память готова к открытиям' : 'Слова снова на связи!',
          style: type.headlineLarge,
        ),
        const SizedBox(height: 12),
        Text(
          ids.isEmpty
              ? 'Сейчас нет слов для этой разминки. Они появятся по расписанию или после ошибки.'
              : 'Закреплено: ${ids.length}. Начислено: ${state!['credited']} XP. Повторные успехи на том же слове сегодня не дают XP заново.',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => context.go(nextLessonRoute(app)),
          child: const Text('К следующей миссии'),
        ),
        TextButton(
          onPressed: () => load(restart: true),
          child: const Text('Подобрать другую разминку'),
        ),
      ]);
    }
    final word = practice.learning.vocabulary[ids[index]]!;
    return pageBody([
      Text(
        'ОСТАНОВКА ПАМЯТИ · ${index + 1} / ${ids.length}',
        style: type.labelSmall,
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          CharacterMoment(
            characterId: 'miko',
            size: 64,
            animate: audio.preferences.reactions,
            state: phase == 2
                ? state!['correct'] == true
                      ? CharacterState.correct
                      : CharacterState.support
                : CharacterState.thinking,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              phase == 0
                  ? 'Вспомним вместе'
                  : phase == 1
                  ? 'Теперь самостоятельно'
                  : state!['correct'] == true
                  ? 'Получилось!'
                  : 'Разберём и попробуем',
              style: type.headlineSmall,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      FlightPanel(accent: true, child: Text(state!['reasons'][index])),
      const SizedBox(height: 24),
      Text(word.ru, style: type.headlineLarge),
      if (phase == 0 || phase == 2 && state!['correct'] == false) ...[
        const SizedBox(height: 8),
        Text(word.en, style: type.headlineMedium),
        const SizedBox(height: 12),
        Text(
          examples[word.id]?.explanation ??
              'Сначала прочитай слово. Затем скроем его, чтобы вспомнить без подсказки.',
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final slow in [false, true])
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await audio.speak(
                    word.en,
                    character: 'miko',
                    slow: slow,
                  );
                  if (!ok && context.mounted) {
                    showMessage(
                      context,
                      audio.lastProblem ?? 'Прочитай слово на экране.',
                    );
                  }
                },
                icon: Icon(
                  slow ? Icons.slow_motion_video : Icons.volume_up_outlined,
                ),
                label: Text(slow ? 'Медленно' : 'Послушать'),
              ),
          ],
        ),
      ],
      if (phase == 1) ...[
        const SizedBox(height: 16),
        TextField(
          key: const Key('practice-input'),
          controller: input,
          enabled: !busy,
          onSubmitted: (_) => next(),
          decoration: const InputDecoration(labelText: 'Вспомни по-английски'),
        ),
      ],
      if (phase == 2 && state!['correct'] == true)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            'Ты вспомнил: ${word.en}. Расписание обновлено.',
            style: type.bodyLarge,
          ),
        ),
      const SizedBox(height: 24),
      FilledButton(
        key: const Key('practice-next'),
        onPressed: busy ? null : next,
        child: Text(
          phase == 0
              ? 'Скрыть и вспомнить'
              : phase == 1
              ? 'Проверить'
              : state!['correct'] == true
              ? 'Следующее слово'
              : 'Попробовать без подсказки',
        ),
      ),
      TextButton(
        onPressed: () => context.go('/'),
        child: const Text('Продолжить позже'),
      ),
    ]);
  }
}
