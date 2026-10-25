import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/database.dart';
import '../domain/course.dart';
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
import 'character_reactions.dart';
import 'rewards_pages.dart';
import '../services/learning_audio.dart';

const exerciseNames = {
  ExerciseType.translate: 'Переведите предложение',
  ExerciseType.choice: 'Выберите перевод',
  ExerciseType.order: 'Соберите предложение',
  ExerciseType.gap: 'Заполните пропуск',
  ExerciseType.listen: 'Поймайте сигнал',
  ExerciseType.pairs: 'Соедините пары',
  ExerciseType.speak: 'Скажите по-английски',
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
  bool unlockedAchievement = false;
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
      prepare();
      setState(() {});
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
        if (mounted) {
          unawaited(
            audio.play(
              finished
                  ? (unlockedAchievement
                        ? SoundEffect.achievement
                        : SoundEffect.complete)
                  : SoundEffect.xp,
            ),
          );
        }
      } else if (result == false) {
        result = null;
      } else {
        final achievementsBefore = app.progress.achievements.toSet();
        final correct = await app.repository.answer(
          session!.id,
          session!.position,
          exercise,
          answer,
          total: lesson!.exercises.length,
        );
        await app.refresh();
        unlockedAchievement = app.progress.achievements.any(
          (a) => !achievementsBefore.contains(a),
        );
        result = correct;
        consecutiveCorrect = correct ? consecutiveCorrect + 1 : 0;
        bestCombo = max(bestCombo, consecutiveCorrect);
        if (mounted) {
          unawaited(
            audio.play(correct ? SoundEffect.correct : SoundEffect.incorrect),
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
      if (mounted) setState(() => busy = false);
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
    final reactions = ref.watch(appProvider).audio.preferences.reactions;
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
          lesson!.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${session!.position + 1} / ${lesson!.exercises.length}',
            ),
          ),
        ],
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
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        result!
                            ? 'Отлично, идём дальше!'
                            : 'Попробуем ещё раз — подсказка ниже задания',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
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
            LessonProgress(done: answered, total: lesson!.exercises.length),
            if (consecutiveCorrect >= 2 && e.story == null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Серия без ошибок: $consecutiveCorrect! Продолжай!',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ],
            if (e.phase.isNotEmpty && e.story == null) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [Chip(label: Text(e.phase))]),
            ],
            const SizedBox(height: 12),
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
                    size: 66,
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
            if (e.story == null) const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                            size: 100,
                            color:
                                Theme.of(context).brightness == Brightness.dark
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
                          ? Theme.of(context).textTheme.headlineMedium
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
                      Text(
                        'Герой: ${CharacterVoiceProfile.forId(e.character).name}',
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 58),
                        ),
                        onPressed: () => speak(),
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('Прослушать'),
                      ),
                      TextButton.icon(
                        onPressed: () => speak(slow: true),
                        icon: const Icon(Icons.slow_motion_video),
                        label: const Text('Медленно'),
                      ),
                      if (e.audio != null)
                        TextButton(
                          onPressed: () => setState(() => revealedAudio = true),
                          child: const Text('Нет звука? Показать фразу'),
                        ),
                      if (revealedAudio && e.audio != null)
                        Text(
                          e.audio!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            LessonCoachCard(lesson: lesson!, exercise: e),
            const SizedBox(height: 24),
            AbsorbPointer(
              absorbing: result != null || busy,
              child: _answerWidget(e),
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: result == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(result),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: (result! ? mintGlow : coral).withValues(
                          alpha: .18,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                result!
                                    ? Icons.check_circle_outline
                                    : Icons.lightbulb_outline,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: XpPop(
                                  enabled: result!,
                                  eventKey: '${e.id}:$result',
                                  child: Text(
                                    result!
                                        ? consecutiveCorrect >= 3
                                              ? 'Отлично! Серия $consecutiveCorrect · +10 XP'
                                              : 'Верно! +10 XP'
                                        : 'Ошибка — разберём её вместе',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (reactions)
                            CharacterReaction(
                              cue: result!
                                  ? CharacterCue.correct
                                  : CharacterCue.support,
                              eventKey: '${e.id}:$result',
                            ),
                          if (reactions)
                            TextButton.icon(
                              onPressed: () async {
                                final cue = result!
                                    ? CharacterCue.correct
                                    : CharacterCue.support;
                                final ok = await audio.speak(
                                  cue.lines.first,
                                  character: cue.id,
                                  locale: 'ru-RU',
                                );
                                if (!ok && context.mounted) {
                                  showMessage(
                                    context,
                                    'Реплика доступна текстом. Проверьте русский голос в настройках звука.',
                                  );
                                }
                              },
                              icon: const Icon(Icons.volume_up_outlined),
                              label: const Text('Послушать Орби'),
                            ),
                          Text(
                            result!
                                ? 'Почему это правильно: ${e.explanation}'
                                : 'Разберём ошибку: ${e.explanation}',
                          ),
                          if (!result!)
                            Text(
                              e.type == ExerciseType.pairs
                                  ? e.pairs
                                        .map((v) => '${v.en} — ${v.ru}')
                                        .join('\n')
                                  : 'Один из верных ответов: ${e.answers.first}',
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Подсказка команды'),
              children: [
                if (reactions)
                  CharacterReaction(
                    cue: CharacterCue.tutor(e.type),
                    eventKey: 'hint:${e.id}',
                    announce: false,
                  ),
                if (reactions)
                  TextButton.icon(
                    onPressed: () async {
                      final cue = CharacterCue.tutor(e.type);
                      final ok = await audio.speak(
                        cue.lines.first,
                        character: cue.id,
                        locale: 'ru-RU',
                      );
                      if (!ok && context.mounted) {
                        showMessage(
                          context,
                          'Реплика доступна текстом. Проверьте русский голос в настройках звука.',
                        );
                      }
                    },
                    icon: const Icon(Icons.volume_up_outlined),
                    label: const Text('Послушать подсказку'),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(lesson!.guide),
                ),
              ],
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
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: order
                  .map(
                    (i) => InputChip(
                      label: Text(e.tokens[i]),
                      onDeleted: () {
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
                                  : null,
                            ),
                            onPressed: () => setState(() => activePair = v.id),
                            child: Text(
                              '${v.en}${pairs.containsKey(v.id) ? ' ✓' : ''}',
                            ),
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
                            onPressed: activePair == null
                                ? null
                                : () {
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
              '${e.pairs.firstWhere((v) => v.id == pair.key).en} → ${pair.value}',
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
            : 'Ваш ответ по-английски',
      ),
      onChanged: (_) {
        setState(() {});
        unawaited(saveDraft());
      },
    );
  }

  Widget _completion(BuildContext context) {
    final app = ref.watch(appProvider);
    final summary = lessonResult ?? ProgressSnapshot();
    final attempts = summary.correct + summary.errors;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: pageBody([
          Center(
            child: SpeakingCharacter(
              audio: audio,
              character: 'orbi',
              state: CharacterState.celebration,
              size: 140,
            ),
          ),
          if (app.audio.preferences.reactions)
            CharacterReaction(
              cue: CharacterCue.completed,
              eventKey: 'completed:${session!.id}',
            ),
          const SizedBox(height: 12),
          Text(
            'Новая орбита освоена!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          Text(
            lesson!.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          SpaceBanner(
            showCharacter: false,
            eyebrow: 'УРОК ЗАВЕРШЁН',
            title: '+${summary.xp} XP',
            subtitle:
                'Верных ответов: ${summary.correct}. Ошибок: ${summary.errors}. Прогресс уже сохранён на устройстве.',
          ),
          if (lesson!.objective != null) ...[
            const SizedBox(height: 16),
            Text(
              'Теперь ты умеешь: ${lesson!.objective}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: 16),
          Metric(
            value: attempts == 0
                ? '—'
                : '${(100 * summary.correct / attempts).round()}%',
            label: 'точность всех попыток в этом уроке',
            icon: Icons.track_changes,
          ),
          const SizedBox(height: 20),
          Text(
            'Всего ${app.progress.xp} XP · уровень ${app.progress.level}',
            textAlign: TextAlign.center,
          ),
          if (bestCombo > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Лучшая серия: $bestCombo ответов подряд',
                textAlign: TextAlign.center,
              ),
            ),
          if (summary.words.values.any((word) => word.errors > 0)) ...[
            const SizedBox(height: 20),
            Text(
              'Вернёмся к сложным словам',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final word in summary.words.entries.where(
              (e) => e.value.errors > 0,
            ))
              if (app.repository.vocabulary[word.key] case final vocabulary?)
                Text(
                  '${vocabulary.en} — ${vocabulary.ru} · плановое повторение ${dayKey((app.progress.words[word.key]?.next ?? DateTime.now()).toLocal())}',
                ),
            TextButton.icon(
              onPressed: () => context.go('/review?mistakes=1'),
              icon: const Icon(Icons.history_edu),
              label: const Text('Разобрать ошибки сейчас'),
            ),
          ],
          const SizedBox(height: 24),
          if (app.inventory.unopened > 0) ...[
            const RewardShortcut(),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Вернуться к путешествию'),
          ),
          TextButton(
            onPressed: () => context.go('/words'),
            child: const Text('Посмотреть новые слова'),
          ),
        ]),
      ),
    );
  }
}
