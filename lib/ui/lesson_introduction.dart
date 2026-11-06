import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/course.dart';
import '../domain/intro_activity.dart';
import 'character_moment.dart';
import '../services/learning_audio.dart';
import 'speech_source.dart';
import 'galaxy_components.dart';
import 'lesson_effects.dart';
import 'lesson_reference.dart';

/// A guided action is available on the very first screen; theory is optional.
class LessonIntroduction extends StatefulWidget {
  final Lesson lesson;
  final Future<void> Function() onStart;
  final Future<void> Function(int)? onStep;
  final Future<void> Function(IntroDraft)? onDraft;
  final IntroDraft? initialDraft;
  final VoidCallback? onClose;
  final int initialStep;
  final LearningAudio audio;
  const LessonIntroduction({
    super.key,
    required this.lesson,
    required this.onStart,
    required this.audio,
    this.onStep,
    this.onDraft,
    this.initialDraft,
    this.onClose,
    this.initialStep = 0,
  });
  @override
  State<LessonIntroduction> createState() => _LessonIntroductionState();
}

class _LessonIntroductionState extends State<LessonIntroduction> {
  late final activities = widget.lesson.guidedIntroduction;
  late int index = (widget.initialDraft?.index ?? widget.initialStep).clamp(
    0,
    activities.length - 1,
  );
  late Map<String, dynamic> actions = {...?widget.initialDraft?.actions};
  final scroll = ScrollController();
  bool busy = false, talking = false;
  IntroActivity get activity => activities[index];
  Map<String, dynamic> get action =>
      Map<String, dynamic>.from(actions[activity.id] ?? {});
  List<int> get chosen => List<int>.from(action['tokens'] ?? []);
  String get answer => activity.tokens.isEmpty
      ? (action['answer'] as String? ?? '')
      : chosen.map((i) => activity.tokens[i]).join(' ');
  bool get solved => action['solved'] == true;
  bool get wrong => action['wrong'] == true;

  Future<void> save(Map<String, dynamic> next, {int? nextIndex}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final draft = IntroDraft(
        index: nextIndex ?? index,
        actions: {...actions, activity.id: next},
      );
      await widget.onDraft?.call(draft);
      if (nextIndex != null) await widget.onStep?.call(nextIndex);
      if (!mounted) return;
      setState(() {
        actions = draft.actions;
        index = draft.index;
      });
      if (nextIndex != null && scroll.hasClients) scroll.jumpTo(0);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить действие. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> listen({bool slow = false}) async {
    if (talking || busy) return;
    setState(() => talking = true);
    try {
      final ok = await widget.audio.speak(
        activity.phrase,
        character: activity.character,
        slow: slow,
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.audio.lastProblem ??
                  'Прочитай фразу: звук сейчас недоступен.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => talking = false);
    }
  }

  Future<void> next() async {
    if (busy || (!solved && answer.isEmpty)) return;
    if (!solved) {
      final correct =
          normalizeAnswer(answer) == normalizeAnswer(activity.answer);
      await save({...action, 'solved': correct, 'wrong': !correct});
      if (mounted && (solved || wrong)) {
        unawaited(
          widget.audio.play(
            correct ? SoundEffect.correct : SoundEffect.incorrect,
          ),
        );
      }
      return;
    }
    if (index + 1 < activities.length) {
      await save(action, nextIndex: index + 1);
      await widget.audio.stop();
    } else {
      setState(() => busy = true);
      try {
        await widget.audio.stop();
        await widget.onStart();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось открыть практику. Попробуйте ещё раз.'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
  }

  void guide() => showLessonReference(context, widget.lesson);

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final theme = Theme.of(context);
    final reveal = action['reveal'] == true || solved;
    final pool = List<int>.generate(
      a.tokens.length,
      (i) => i,
    ).reversed.toList();
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Попробуем вместе'),
          leading: widget.onClose == null
              ? null
              : IconButton(
                  tooltip: 'Закрыть и сохранить',
                  icon: const Icon(Icons.close),
                  onPressed: busy
                      ? null
                      : () async {
                          await widget.audio.stop();
                          if (mounted) widget.onClose!();
                        },
                ),
          actions: [
            IconButton(
              tooltip: 'Справочник',
              onPressed: guide,
              icon: const Icon(Icons.menu_book_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      children: [
                        LessonProgress(
                          done: index + (solved ? 1 : 0),
                          total: activities.length,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SpeakingCharacter(
                              audio: widget.audio,
                              character: a.character,
                              size: 52,
                              state: solved
                                  ? CharacterState.correct
                                  : wrong
                                  ? CharacterState.support
                                  : index == 0
                                  ? CharacterState.greeting
                                  : CharacterState.thinking,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                index == 0
                                    ? widget.lesson.objective ??
                                          widget.lesson.title
                                    : 'Теперь попробуй сам.',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        QuestionEntrance(
                          questionId: a.id,
                          enabled: widget.audio.preferences.reactions,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Material(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: .4),
                                borderRadius: BorderRadius.circular(24),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.phrase,
                                        style: theme.textTheme.headlineMedium,
                                      ),
                                      if (a.pronunciation != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            a.pronunciation!,
                                            style: theme.textTheme.titleMedium,
                                          ),
                                        ),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          IconButton(
                                            tooltip: 'Послушать пример',
                                            onPressed: talking || busy
                                                ? null
                                                : listen,
                                            icon: const Icon(
                                              Icons.volume_up_rounded,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: talking || busy
                                                ? null
                                                : () => listen(slow: true),
                                            child: const Text('Медленнее'),
                                          ),
                                          TextButton(
                                            key: const Key('intro-reveal'),
                                            onPressed: busy
                                                ? null
                                                : () => save({
                                                    ...action,
                                                    'reveal': !reveal,
                                                  }),
                                            child: Text(
                                              reveal
                                                  ? 'Скрыть перевод'
                                                  : 'Перевод',
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (reveal)
                                        Text(
                                          a.translation,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(a.prompt, style: theme.textTheme.titleLarge),
                              const SizedBox(height: 12),
                              for (var i = 0; i < a.options.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: AnswerTile(
                                    key: ValueKey('intro-option-$i'),
                                    text: a.options[i],
                                    index: i,
                                    selected: answer == a.options[i],
                                    verdict: solved
                                        ? true
                                        : wrong
                                        ? false
                                        : null,
                                    onPressed: () {
                                      if (!busy && !solved) {
                                        save({
                                          ...action,
                                          'answer': a.options[i],
                                          'wrong': false,
                                        });
                                      }
                                    },
                                  ),
                                ),
                              if (a.tokens.isNotEmpty) ...[
                                Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 64,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    answer.isEmpty
                                        ? 'Нажимай на слова ниже'
                                        : answer,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final i in pool)
                                      ActionChip(
                                        key: ValueKey('intro-token-$i'),
                                        label: Text(a.tokens[i]),
                                        onPressed:
                                            busy || solved || chosen.contains(i)
                                            ? null
                                            : () => save({
                                                ...action,
                                                'tokens': [...chosen, i],
                                                'wrong': false,
                                              }),
                                      ),
                                    TextButton(
                                      key: const Key('intro-undo'),
                                      onPressed:
                                          busy || solved || chosen.isEmpty
                                          ? null
                                          : () => save({
                                              ...action,
                                              'tokens': chosen..removeLast(),
                                              'wrong': false,
                                            }),
                                      child: const Text('Убрать слово'),
                                    ),
                                  ],
                                ),
                              ],
                              if (wrong || solved)
                                Semantics(
                                  liveRegion: true,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      solved
                                          ? 'Получилось! ${a.explanation}'
                                          : 'Пока не совпало. Открой перевод или сверись с образцом и попробуй ещё раз.',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ),
                              SpeechSourceLabel(
                                audio: widget.audio,
                                character: a.character,
                                text: a.phrase,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        if (index > 0)
                          IconButton(
                            key: const Key('teaching-back'),
                            tooltip: 'К предыдущему примеру',
                            onPressed: busy
                                ? null
                                : () => save(action, nextIndex: index - 1),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        Expanded(
                          child: FilledButton(
                            key: const Key('teaching-next'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                            ),
                            onPressed: busy || (!solved && answer.isEmpty)
                                ? null
                                : next,
                            child: Text(
                              busy
                                  ? 'Сохраняем…'
                                  : !solved
                                  ? 'Проверить'
                                  : index + 1 == activities.length
                                  ? 'К заданиям'
                                  : 'Следующий пример',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
