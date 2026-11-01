import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/database.dart';
import '../domain/course.dart';
import '../domain/languages.dart';
import '../domain/progress.dart';
import '../domain/learning_recap.dart';
import '../services/device.dart';
import 'design.dart';
import 'lesson_effects.dart';
import 'lesson_coach.dart';
import 'lesson_introduction.dart';
import 'dialogue_scene.dart';
import 'character_moment.dart';
import 'speech_source.dart';
import 'galaxy_components.dart';
import 'lesson_audio_toggle.dart';
import 'flight_completion.dart';
import 'mission_checkpoint.dart';
import 'story_response.dart';
import 'answer_signal.dart';
import 'package:flutter/services.dart';
import '../services/learning_audio.dart';

const exerciseNames = {
  ExerciseType.translate: 'Переведите предложение',
  ExerciseType.choice: 'Выберите перевод',
  ExerciseType.order: 'Соберите предложение',
  ExerciseType.gap: 'Заполните пропуск',
  ExerciseType.listen: 'Поймайте сигнал',
  ExerciseType.pairs: 'Соедините пары',
  ExerciseType.speak: 'Произнесите фразу',
  ExerciseType.correct: 'Исправьте ошибку',
  ExerciseType.review: 'Вспомните слово',
  ExerciseType.dialogue: 'Продолжите диалог',
};

class LessonScreen extends ConsumerStatefulWidget {
  final String lessonId;
  final bool demo;
  const LessonScreen({super.key, required this.lessonId, this.demo = false});
  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  Lesson? lesson;
  ProgressSnapshot? lessonResult;
  Session? session;
  String? error;
  final input = TextEditingController();
  final voice = VoiceService();
  late final LearningAudio audio;
  bool completionMoment = false;
  bool storyNeededHelp = false;
  bool showCheckpoint = false;
  int checkpointXp = 0;
  Set<String> initialGrants = {}, initialAchievements = {};
  int consecutiveCorrect = 0;
  int bestCombo = 0;
  List<int> order = [];
  Map<String, String> pairs = {};
  String? activePair;
  bool busy = false, finished = false, revealedAudio = false;
  bool showTeaching = false;
  int teachingStep = 0;
  bool? result;
  List<String> options = [];
  List<int> tokenPool = [];
  List<Vocabulary> rightPairs = [];
  @override
  void initState() {
    super.initState();
    audio = ref.read(appProvider).audio;
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final app = ref.read(appProvider);
      initialGrants = app.inventory.grants.keys.toSet();
      initialAchievements = app.globalProgress.achievements.toSet();
      if (app.course.id != StudyCourse.forContent(widget.lessonId).id) {
        await app.selectCourse(StudyCourse.forContent(widget.lessonId).id);
      }
      final loaded = await app.repository.lesson(widget.lessonId);
      // Guards also apply to direct deep links, not just the map's buttons.
      if (loaded.order > 0 &&
          !app.progress.completed.contains(
            app.repository.catalog[loaded.order - 1].id,
          ) &&
          !app.progress.completed.contains(loaded.id)) {
        throw StateError('Сначала пройдите предыдущий урок.');
      }
      final material = await app.repository.startLesson(
        widget.lessonId,
        demo: widget.demo,
      );
      final saved = material.session;
      // Resolve async session state before exposing the quiz to build().
      final shouldTeach =
          !saved.done &&
          saved.position == 0 &&
          material.lesson.teachingSteps.isNotEmpty &&
          !await app.repository.hasTeachingSeen(saved.id);
      final summary = saved.done ? await _readSummary(saved.id) : null;
      final recap = LearningRecap.fromEvents(
        await app.repository.allEvents(),
        saved.id,
      );
      final savedTeachingStep = shouldTeach
          ? await app.repository.teachingStep(saved.id)
          : 0;
      if (!mounted) return;
      // Map notices must not follow the student and cover lesson navigation.
      ScaffoldMessenger.of(context).clearSnackBars();
      lesson = material.lesson;
      session = saved;
      showTeaching = shouldTeach;
      teachingStep = savedTeachingStep;
      lessonResult = summary;
      consecutiveCorrect = recap.streak;
      bestCombo = recap.best;
      storyNeededHelp = recap.difficultWords.isNotEmpty;
      prepare();
      await checkCheckpoint();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              error = e is StateError ? e.message : 'Не удалось открыть урок.',
        );
      }
    }
  }

  Exercise get exercise => lesson!.exercises[session!.position];
  Future<void> checkCheckpoint() async {
    if (session!.done ||
        lesson!.exercises.length < 8 ||
        session!.position != lesson!.exercises.length ~/ 2 ||
        session!.draft.isNotEmpty) {
      return;
    }
    final repo = ref.read(appProvider).repository;
    if (await repo.setting(
          'kvesmos.stage.seen.v1:${session!.id}:${session!.position}',
        ) ==
        'true') {
      return;
    }
    checkpointXp = ProgressSnapshot.fromEvents(
      (await repo.allEvents()).where((e) => e.data['session'] == session!.id),
    ).xp;
    if (mounted) showCheckpoint = true;
  }

  Future<void> continueCheckpoint() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref
          .read(appProvider)
          .repository
          .setSetting(
            'kvesmos.stage.seen.v1:${session!.id}:${session!.position}',
            'true',
          );
      if (mounted) setState(() => showCheckpoint = false);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Не удалось сохранить переход. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restartUpdated() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await audio.stop();
      final material = await ref
          .read(appProvider)
          .repository
          .restartUpdated(widget.lessonId, session!.id);
      if (!mounted) return;
      lesson = material.lesson;
      session = material.session;
      showTeaching = material.lesson.teachingSteps.isNotEmpty;
      teachingStep = 0;
      consecutiveCorrect = 0;
      bestCombo = 0;
      lessonResult = null;
      prepare();
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Не удалось сменить формат. Старый урок сохранён.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void prepare() {
    input.clear();
    order = [];
    pairs = {};
    activePair = null;
    result = null;
    revealedAudio = false;
    if (session!.done) {
      finished = true;
      return;
    }
    final random = Random(exercise.id.hashCode);
    options = List.of(exercise.options)..shuffle(random);
    tokenPool = List.generate(exercise.tokens.length, (i) => i)
      ..shuffle(random);
    rightPairs = List.of(exercise.pairs)..shuffle(random);
    try {
      if (session!.draft.isNotEmpty) {
        final d = jsonDecode(session!.draft);
        input.text = d['text'] ?? '';
        order = List<int>.from(d['order'] ?? []);
        pairs = Map<String, String>.from(d['pairs'] ?? {});
      }
    } catch (_) {
      input.clear();
      order = [];
      pairs = {};
    }
  }

  Future<void> saveDraft() async {
    if (session == null || result != null || finished) return;
    try {
      await ref
          .read(appProvider)
          .repository
          .draft(
            session!.id,
            session!.position,
            jsonEncode({'text': input.text, 'order': order, 'pairs': pairs}),
          );
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Черновик не сохранился. Проверьте свободное место.',
        );
      }
    }
  }

  String get answer {
    if (exercise.type == ExerciseType.order) {
      return order.map((i) => exercise.tokens[i]).join(' ');
    }
    if (exercise.type == ExerciseType.pairs) {
      return pairs.length == exercise.pairs.length &&
              exercise.pairs.every((v) => pairs[v.id] == v.ru)
          ? 'matched'
          : 'mismatch';
    }
    return input.text;
  }

  bool get canCheck => exercise.type == ExerciseType.pairs
      ? pairs.length == exercise.pairs.length
      : answer.trim().isNotEmpty;
  Future<void> check() async {
    if (busy) return;
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      final app = ref.read(appProvider);
      await audio.stop();
      if (result == true) {
        await voice.stop();
        session = await app.repository.session(session!.id);
        if (session!.done) lessonResult = await _readSummary(session!.id);
        prepare();
        await checkCheckpoint();
        if (mounted && finished) {
          try {
            completionMoment = await app.claimExperienceMoment(
              'complete:${session!.id}',
            );
          } catch (_) {
            // Presentation bookkeeping must not hide an already saved result.
            completionMoment = false;
          }
          if (mounted && completionMoment) {
            unawaited(
              audio.play(
                app.inventory.grants.keys.any(
                      (id) => !initialGrants.contains(id),
                    )
                    ? SoundEffect.achievement
                    : SoundEffect.complete,
              ),
            );
          }
        }
      } else if (result == false) {
        result = null;
      } else {
        final correct = await app.repository.answer(
          session!.id,
          session!.position,
          exercise,
          answer,
          total: lesson!.exercises.length,
        );
        await app.refresh();
        result = correct;
        if (!correct) storyNeededHelp = true;
        if (audio.preferences.reactions &&
            mounted &&
            !MediaQuery.disableAnimationsOf(context)) {
          unawaited(
            correct
                ? HapticFeedback.lightImpact()
                : HapticFeedback.selectionClick(),
          );
        }
        consecutiveCorrect = correct ? consecutiveCorrect + 1 : 0;
        bestCombo = max(bestCombo, consecutiveCorrect);
        if (mounted) {
          unawaited(
            audio.play(
              !correct
                  ? SoundEffect.incorrect
                  : consecutiveCorrect >= 3 && consecutiveCorrect % 3 == 0
                  ? SoundEffect.xp
                  : SoundEffect.correct,
            ),
          );
        }
        unawaited(app.synchronize());
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Не удалось сохранить ответ. Он не потерян — попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<ProgressSnapshot> _readSummary(String sessionId) async =>
      ProgressSnapshot.fromEvents(
        (await ref.read(appProvider).repository.allEvents()).where(
          (e) => e.data['session'] == sessionId,
        ),
      );

  Future<void> speak({bool slow = false}) async {
    final question = exercise;
    await voice.stop();
    if (!await audio.speak(
          question.audio ?? question.prompt,
          character: question.character,
          slow: slow,
        ) &&
        mounted &&
        question.id == exercise.id) {
      setState(() => revealedAudio = true);
      showMessage(
        context,
        audio.lastProblem ??
            'Прослушивание прервано. Фразу можно прочитать и продолжить урок.',
      );
    }
  }

  @override
  void dispose() {
    unawaited(voice.stop());
    unawaited(audio.stop());
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.close),
          ),
        ),
        body: pageBody([
          Text(error!),
          FilledButton(
            onPressed: () => context.go('/offline'),
            child: const Text('Офлайн-уроки'),
          ),
        ]),
      );
    }
    if (lesson == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (finished) return _completion(context);
    if (showCheckpoint) {
      return MissionCheckpoint(
        lesson: lesson!,
        position: session!.position,
        xp: checkpointXp,
        animate: audio.preferences.reactions,
        busy: busy,
        onContinue: continueCheckpoint,
      );
    }
    if (showTeaching) {
      return LessonIntroduction(
        lesson: lesson!,
        audio: audio,
        initialStep: teachingStep,
        onClose: () => context.go('/'),
        onStep: (step) async {
          await ref
              .read(appProvider)
              .repository
              .saveTeachingStep(session!.id, step);
          teachingStep = step;
        },
        onStart: () async {
          if (busy) return;
          setState(() => busy = true);
          try {
            await ref
                .read(appProvider)
                .repository
                .markTeachingSeen(session!.id);
            if (mounted) setState(() => showTeaching = false);
          } catch (_) {
            if (context.mounted) {
              showMessage(context, 'Не удалось сохранить начало практики.');
            }
          } finally {
            if (mounted) setState(() => busy = false);
          }
        },
      );
    }
    final e = exercise;
    ref.watch(appProvider);
    final answered = session!.position + (result == true ? 1 : 0);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Закрыть и сохранить',
          onPressed: () async {
            await saveDraft();
            if (context.mounted) context.go('/');
          },
          icon: const Icon(Icons.close),
        ),
        title: Text(
          'Шаг ${session!.position + 1} из ${lesson!.exercises.length}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: const [LessonAudioToggle(), SizedBox(width: 8)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: LessonProgress(
              done: answered,
              total: lesson!.exercises.length,
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (result != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .28,
                      ),
                      child: SingleChildScrollView(
                        key: ValueKey('feedback:${e.id}:$result'),
                        child: AnswerSignal(
                          explanation: e.explanation,
                          correction: result == false
                              ? e.type == ExerciseType.pairs
                                    ? e.pairs
                                          .map((v) => '${v.en} — ${v.ru}')
                                          .join('\n')
                                    : 'Верный вариант: ${e.answers.first}'
                              : null,
                          key: ValueKey(
                            '${session!.id}:${session!.position}:$result',
                          ),
                          correct: result!,
                          animate: audio.preferences.reactions,
                          combo: consecutiveCorrect,
                        ),
                      ),
                    ),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                  ),
                  onPressed: busy || (!canCheck && result == null)
                      ? null
                      : check,
                  child: Text(
                    busy
                        ? 'Сохраняем…'
                        : result == true
                        ? 'Дальше'
                        : result == false
                        ? 'Попробовать снова'
                        : 'Проверить',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: QuestionEntrance(
          questionId: e.id,
          child: pageBody([
            if (e.phase.isEmpty &&
                ref
                    .read(appProvider)
                    .repository
                    .updatedMaterials
                    .containsKey(widget.lessonId))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Это ранее начатый урок старого формата. Можно сразу перейти к разнообразным заданиям. Заработанный XP и прежние ответы останутся в истории.',
                      ),
                      FilledButton(
                        onPressed: busy ? null : restartUpdated,
                        child: const Text('Начать обновлённый урок'),
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              [
                if (e.phase.isNotEmpty) e.phase.toUpperCase(),
                if (consecutiveCorrect >= 2) 'Серия: $consecutiveCorrect',
              ].join('  ·  '),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),
            if (e.story != null)
              StoryPanel(story: e.story!, completed: result == true),
            if (e.story == null)
              Row(
                children: [
                  SpeakingCharacter(
                    audio: audio,
                    character: e.character,
                    state: result == true
                        ? CharacterState.correct
                        : result == false
                        ? CharacterState.support
                        : CharacterState.thinking,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      e.visual != null
                          ? 'Узнай предмет'
                          : e.audio != null && e.options.isNotEmpty
                          ? 'Слушай и выбирай'
                          : exerciseNames[e.type]!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.introduction != null) ...[
                    Text(
                      e.introduction!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (e.visual != null) ...[
                    Center(
                      child: Semantics(
                        label:
                            'Иллюстрация: ${e.visual == 'book'
                                ? 'книга'
                                : e.visual == 'pen'
                                ? 'ручка'
                                : 'сумка'}',
                        child: Icon(
                          switch (e.visual) {
                            'book' => Icons.menu_book_rounded,
                            'pen' => Icons.edit_rounded,
                            _ => Icons.backpack_rounded,
                          },
                          size: 64,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? turquoise
                              : cosmicBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (e.scene != null) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(e.story == null ? 12 : 0),
                      decoration: BoxDecoration(
                        color: turquoise.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: DialogueScene(
                        scene: e.scene!,
                        audio: audio,
                        reply: result == true ? answer : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    e.prompt,
                    style: e.story == null
                        ? Theme.of(context).textTheme.titleLarge
                        : Theme.of(context).textTheme.titleMedium,
                  ),
                  if (e.audio != null ||
                      e.type == ExerciseType.listen ||
                      e.type == ExerciseType.speak) ...[
                    const SizedBox(height: 20),
                    SpeechSourceLabel(
                      audio: audio,
                      character: e.character,
                      text: e.audio ?? e.prompt,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => speak(),
                          icon: const Icon(Icons.volume_up_outlined),
                          label: const Text('Прослушать'),
                        ),
                        TextButton.icon(
                          onPressed: () => speak(slow: true),
                          icon: const Icon(Icons.slow_motion_video),
                          label: const Text('Медленно'),
                        ),
                      ],
                    ),
                    if (e.audio != null)
                      TextButton(
                        onPressed: () => setState(() => revealedAudio = true),
                        child: const Text('Нет звука? Показать фразу'),
                      ),
                    if (revealedAudio && e.audio != null)
                      Text(
                        e.audio!,
                        key: const Key('audio-transcript'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            AbsorbPointer(
              absorbing: result != null || busy,
              child: _answerWidget(e),
            ),
            LessonCoachCard(lesson: lesson!, exercise: e),
            const SizedBox(height: 12),
            if (e.type == ExerciseType.speak) ...[
              OutlinedButton.icon(
                onPressed: result != null || busy
                    ? null
                    : () async {
                        await audio.stop();
                        final ok = await voice.listen(
                          (text) {
                            if (mounted && result == null) {
                              setState(() => input.text = text);
                              unawaited(saveDraft());
                            }
                          },
                          (message) {
                            if (mounted) showMessage(context, message);
                          },
                          language: ref.read(appProvider).course.language,
                        );
                        if (!ok && context.mounted) {
                          showMessage(
                            context,
                            'Микрофон или распознавание недоступны. Введите фразу вручную.',
                          );
                        }
                      },
                icon: const Icon(Icons.mic_none),
                label: const Text('Произнести фразу'),
              ),
              const SizedBox(height: 10),
              const Text(
                'Сравниваем распознанный текст с фразой. Это не оценка произношения. Можно ввести текст вручную.',
              ),
            ],
            if (e.story != null && result != null)
              StoryResponse(
                key: ValueKey('${e.id}:$result'),
                exercise: e,
                correct: result!,
                neededHelp: storyNeededHelp,
                audio: audio,
              ),
          ]),
        ),
      ),
    );
  }

  Widget _answerWidget(Exercise e) {
    if (e.options.isNotEmpty) {
      return Column(
        children: options
            .map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnswerTile(
                  verdict: result,
                  text: v,
                  index: options.indexOf(v),
                  selected: input.text == v,
                  onPressed: () {
                    unawaited(audio.play(SoundEffect.tap));
                    setState(() => input.text = v);
                    unawaited(saveDraft());
                  },
                ),
              ),
            )
            .toList(),
      );
    }
    if (e.type == ExerciseType.order) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 90),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: violet),
              borderRadius: BorderRadius.circular(18),
            ),
            child: order.isEmpty
                ? Text(
                    'Нажимай слова в нужном порядке',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: order
                        .map(
                          (i) => InputChip(
                            label: Text(e.tokens[i]),
                            onDeleted: () {
                              unawaited(audio.play(SoundEffect.tap));
                              setState(() => order.remove(i));
                              unawaited(saveDraft());
                            },
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tokenPool
                .map(
                  (i) => ActionChip(
                    label: Text(e.tokens[i]),
                    onPressed: order.contains(i)
                        ? null
                        : () {
                            unawaited(audio.play(SoundEffect.tap));
                            setState(() => order.add(i));
                            unawaited(saveDraft());
                          },
                  ),
                )
                .toList(),
          ),
        ],
      );
    }
    if (e.type == ExerciseType.pairs) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Выберите слово слева, затем перевод справа. Для изменения пары выберите слово ещё раз.',
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: e.pairs
                      .map(
                        (v) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: activePair == v.id
                                  ? turquoise.withValues(alpha: .25)
                                  : pairs.containsKey(v.id)
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                              minimumSize: const Size(double.infinity, 52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () {
                              unawaited(audio.play(SoundEffect.tap));
                              setState(() => activePair = v.id);
                            },
                            child: Text(v.en),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: rightPairs
                      .map(
                        (v) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              backgroundColor: pairs.containsValue(v.ru)
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                            ),
                            onPressed: activePair == null
                                ? null
                                : () {
                                    unawaited(audio.play(SoundEffect.tap));
                                    setState(() {
                                      pairs.removeWhere(
                                        (key, value) => value == v.ru,
                                      );
                                      pairs[activePair!] = v.ru;
                                      activePair = null;
                                    });
                                    unawaited(saveDraft());
                                  },
                            child: Text(v.ru),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
          ...pairs.entries.map(
            (pair) => Text(
              '${e.pairs.firstWhere((v) => v.id == pair.key).en} — ${pair.value}',
            ),
          ),
        ],
      );
    }
    return TextField(
      controller: input,
      minLines: 2,
      maxLines: 4,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        hintText: e.type == ExerciseType.gap
            ? 'Пропущенное слово'
            : 'Ответ на изучаемом языке',
      ),
      onChanged: (_) {
        setState(() {});
        unawaited(saveDraft());
      },
    );
  }

  Widget _completion(BuildContext context) {
    final app = ref.watch(appProvider);
    return FlightCompletion(
      app: app,
      lesson: lesson!,
      summary: lessonResult ?? ProgressSnapshot(),
      celebrate: completionMoment,
      bestCombo: bestCombo,
      newChests: app.inventory.grants.keys
          .where((id) => !initialGrants.contains(id))
          .length,
      achievements: app.globalProgress.achievements
          .where((id) => !initialAchievements.contains(id))
          .toList(),
    );
  }
}
