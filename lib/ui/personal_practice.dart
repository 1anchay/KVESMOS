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
import '../services/device.dart';
import 'speech_source.dart';

class PersonalPracticePage extends ConsumerStatefulWidget {
  final PracticeMode mode;
  final List<String> lessonIds;
  const PersonalPracticePage({
    super.key,
    this.mode = PracticeMode.warmup,
    this.lessonIds = const [],
  });
  @override
  ConsumerState<PersonalPracticePage> createState() =>
      _PersonalPracticePageState();
}

class _PersonalPracticePageState extends ConsumerState<PersonalPracticePage> {
  late final PracticeRepository practice;
  late final LearningAudio audio;
  final input = TextEditingController();
  final voice = VoiceService();
  Map<String, String> dialogues = {};
  bool showTranscript = false;
  Map<String, dynamic>? state;
  Map<String, Exercise> examples = {};
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final app = ref.read(appProvider);
    practice = PracticeRepository(
      app.repository,
      mode: widget.mode,
      lessonIds: widget.lessonIds,
    );
    audio = app.audio;
    load();
  }

  Future<void> load({bool restart = false}) async {
    try {
      final value = await practice.open(restart: restart);
      final context = await practice.learning.mistakeExamples();
      final scenes = widget.mode == PracticeMode.dialogue
          ? await practice.dialogueContexts()
          : <String, String>{};
      if (mounted) {
        setState(() {
          state = value;
          examples = context;
          dialogues = scenes;
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
    unawaited(voice.stop());
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
      await voice.stop();
      await audio.stop();
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
          if (value['phase'] == 0) showTranscript = false;
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
    final listening = widget.mode == PracticeMode.listen;
    Future<void> play(bool slow) async {
      final ok = await audio.speak(word.en, character: 'miko', slow: slow);
      if (!ok && context.mounted && state?['index'] == index) {
        setState(() => showTranscript = true);
        showMessage(context, audio.lastProblem ?? 'Прочитай фразу на экране.');
      }
    }

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
      if (widget.mode == PracticeMode.dialogue &&
          dialogues[word.id] != null) ...[
        Text(
          dialogues[word.id]!.replaceAll(word.en, '…'),
          style: type.bodyLarge,
        ),
        const SizedBox(height: 12),
        const Text('Восстанови пропущенную реплику по смыслу.'),
      ],
      Text(
        listening && !showTranscript && phase != 2
            ? 'Поймай сигнал и запиши услышанное'
            : word.ru,
        style: type.headlineLarge,
      ),
      if (listening) ...[
        SpeechSourceLabel(audio: audio, character: 'miko', text: word.en),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => play(false),
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Послушать'),
            ),
            TextButton(
              onPressed: () => play(true),
              child: const Text('Медленнее'),
            ),
            TextButton(
              onPressed: () => setState(() => showTranscript = true),
              child: const Text('Показать текст'),
            ),
          ],
        ),
        if (showTranscript || phase == 2) Text(word.en, style: type.titleLarge),
      ],
      if (!listening &&
          (phase == 0 || phase == 2 && state!['correct'] == false)) ...[
        const SizedBox(height: 8),
        Text(word.en, style: type.headlineMedium),
        if (word.pronunciation != null) Text(word.pronunciation!),
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
        if (widget.mode == PracticeMode.speak) ...[
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    await audio.stop();
                    final ok = await voice.listen(
                      (text) {
                        if (mounted &&
                            !busy &&
                            state?['index'] == index &&
                            state?['phase'] == 1) {
                          setState(() => input.text = text);
                          unawaited(practice.draft(index, text));
                        }
                      },
                      (message) {
                        if (mounted) showMessage(context, message);
                      },
                      language: app.course.language,
                    );
                    if (!ok && context.mounted) {
                      showMessage(
                        context,
                        'Распознавание недоступно. Можно ввести ответ текстом.',
                      );
                    }
                  },
            icon: const Icon(Icons.mic_none),
            label: const Text('Произнести фразу'),
          ),
          const Text(
            'Проверяем распознанный текст, а не произношение. Текстовый ответ доступен всегда.',
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const Key('practice-input'),
          controller: input,
          enabled: !busy,
          onSubmitted: (_) => next(),
          onChanged: (text) => unawaited(practice.draft(index, text)),
          decoration: const InputDecoration(
            labelText: 'Вспомни на изучаемом языке',
          ),
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
              ? listening
                    ? 'Записать услышанное'
                    : 'Скрыть и вспомнить'
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
