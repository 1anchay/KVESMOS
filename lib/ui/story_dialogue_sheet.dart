import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/story_repository.dart';
import '../domain/course.dart' show normalizeAnswer;
import '../domain/knowledge.dart';
import '../domain/story_dialogue.dart';
import '../services/learning_audio.dart';
import 'character_moment.dart';
import 'flight_ui.dart';
import 'knowledge_widgets.dart';

Future<void> showStoryDialogue(
  BuildContext context,
  StoryScene scene,
  StoryRepository repository,
  LanguageContext language,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => StoryDialogueSheet(
    scene: scene,
    repository: repository,
    language: language,
  ),
);

class StoryDialogueSheet extends StatefulWidget {
  const StoryDialogueSheet({
    super.key,
    required this.scene,
    required this.repository,
    required this.language,
  });
  final StoryScene scene;
  final StoryRepository repository;
  final LanguageContext language;
  @override
  State<StoryDialogueSheet> createState() => _StorySheetState();
}

class _StorySheetState extends State<StoryDialogueSheet> {
  StoryView? view;
  ({StoryView checked, String answer, StoryVerdict verdict})? outcome;
  int? selection;
  String? error;
  bool busy = false;
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(open());
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> open() async {
    try {
      final opened = await widget.repository.open(widget.scene);
      await widget.language.refresh();
      if (mounted) {
        unawaited(widget.language.audio.play(SoundEffect.radio));
        setState(() {
          view = opened;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Не удалось открыть связь. Попробуй ещё раз.');
      }
    }
  }

  void rewind() {
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> move(StoryMove action, [Object? input]) async {
    if (busy || outcome != null) return;
    final current = view!;
    final node = widget.scene.nodes[current.run.cursor]!;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final updated = await widget.repository.move(
        widget.scene,
        current.run.revision,
        action,
        input,
      );
      final moved = updated.run.cursor != current.run.cursor;
      final verdict = updated.verdict;
      if (moved || verdict != null) await widget.language.refresh();
      if (!mounted) return;
      setState(() {
        view = updated;
        if (node is StoryPractice &&
            verdict != null &&
            verdict != StoryVerdict.unsupported) {
          final task = node.tasks[current.run.variant];
          outcome = (
            checked: current,
            verdict: verdict,
            answer: action == StoryMove.example
                ? task.answers.first
                : task.format == StoryFormat.order
                ? task.joined(current.run.draft)
                : input as String,
          );
        }
        if (moved) selection = null;
        if (verdict == StoryVerdict.unsupported) {
          error =
              'Эту реплику нельзя проверить. Выбери ответ или воспользуйся примером.';
        }
      });
      if (moved || verdict != null) rewind();
      if (updated.run.revision != current.run.revision) {
        final effect = switch (action) {
          StoryMove.token =>
            current.run.draft.contains(input)
                ? SoundEffect.returnToken
                : SoundEffect.token,
          StoryMove.choice =>
            node is StoryDecision &&
                    node.choices.any((c) => c.id == input && c.trust != null)
                ? SoundEffect.trust
                : SoundEffect.confirm,
          StoryMove.submit => switch (verdict) {
            StoryVerdict.accepted => SoundEffect.correct,
            StoryVerdict.incorrect => SoundEffect.incorrect,
            _ => SoundEffect.confirm,
          },
          StoryMove.next =>
            updated.run.finished ? SoundEffect.complete : SoundEffect.confirm,
          StoryMove.example || StoryMove.help => SoundEffect.tap,
        };
        unawaited(widget.language.audio.play(effect));
      }
      if (updated.run.finished && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Не удалось сохранить реплику. Попробуй ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  double progress(StoryRun? run) {
    if (run == null) return 0;
    if (run.finished) return 1;
    int remaining(String id) =>
        1 +
        widget.scene.nodes[id]!.targets.fold<int>(
          0,
          (a, b) => math.max(a, remaining(b)),
        );
    return (run.path.length - 1) /
        (run.path.length - 1 + remaining(run.cursor));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.language,
    builder: (context, _) {
      final colors = FlightPalette.of(context);
      final state = outcome?.checked ?? view;
      final run = state?.run;
      final node = run == null ? null : widget.scene.nodes[run.cursor];
      return FractionallySizedBox(
        heightFactor: .92,
        child: Material(
          key: const Key('story-shell'),
          color: colors.background,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(5, 6, 5, 3),
                      child: Row(
                        children: [
                          IconButton(
                            key: const Key('story-close'),
                            tooltip: 'Закрыть связь',
                            color: colors.text,
                            onPressed: busy
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.scene.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.secondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: progress(run),
                                    minHeight: 7,
                                    color: colors.accent,
                                    backgroundColor: colors.line,
                                    semanticsLabel: 'Прогресс разговора',
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const FlightThemePicker(key: Key('story-theme')),
                        ],
                      ),
                    ),
                    Divider(color: colors.line, height: 1),
                    Expanded(
                      child: ListView(
                        key: const Key('story-sheet'),
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                        children: [
                          if (state == null && error == null)
                            Center(
                              child: CircularProgressIndicator(
                                color: colors.accent,
                              ),
                            ),
                          if (state == null && error != null)
                            FlightControl(
                              label: error!,
                              onTap: busy ? null : open,
                              style: FlightControlStyle.primary,
                            ),
                          if (node != null) ...[
                            if (node is StoryPractice)
                              heading(node.tasks[run!.variant], colors),
                            speaker(node, run!, colors),
                            if (outcome case final result?)
                              feedback(
                                node as StoryPractice,
                                run,
                                result.answer,
                                result.verdict,
                                colors,
                              )
                            else if (node is StoryPractice)
                              ...practice(node, run, colors)
                            else if (node is StoryDecision) ...[
                              const SizedBox(height: 18),
                              Text('Твоё решение', style: _heading(colors, 20)),
                              const SizedBox(height: 10),
                              for (final choice in node.choices)
                                if (choice.requiresTrust == null ||
                                    state!.save.trust(choice.requiresTrust!) >
                                        0)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: FlightControl(
                                      key: Key('story-choice-${choice.id}'),
                                      label: choice.label,
                                      icon: Icons.alt_route,
                                      onTap: busy
                                          ? null
                                          : () => move(
                                              StoryMove.choice,
                                              choice.id,
                                            ),
                                    ),
                                  ),
                            ],
                          ],
                          if (state != null && error != null)
                            Text(
                              error!,
                              style: TextStyle(color: colors.warning),
                            ),
                        ],
                      ),
                    ),
                    if (node != null) footer(node, run!, colors),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  TextStyle _heading(FlightPalette c, [double size = 23]) => TextStyle(
    color: c.text,
    fontSize: size,
    fontWeight: FontWeight.w800,
    height: 1.14,
  );

  Widget heading(StoryTask task, FlightPalette c) {
    final sentence = _sentence(task);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        sentence == null
            ? task.prompt
            : switch (task.format) {
                StoryFormat.word => 'Вставь слово',
                _ => 'Вставь выражение',
              },
        key: Key('story-task-${task.format.name}'),
        style: _heading(c),
      ),
    );
  }

  Widget speaker(StoryNode node, StoryRun run, FlightPalette c) {
    final line = node is StoryLine ? node : null;
    final term = line?.term == null
        ? null
        : KnowledgeCatalog.lexicon[line!.term]!;
    final englishOnly =
        term != null &&
        widget.language.mode != ImmersionMode.beginner &&
        widget.language.snapshot.canUseEnglishSentence(
          line!.sentenceSkills.map((id) => KnowledgeCatalog.skills[id]!),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: IgnorePointer(
                  child: SpeakingCharacter(
                    audio: widget.language.audio,
                    character: node.speaker.name,
                    size: 54,
                    state: run.wrong
                        ? CharacterState.support
                        : CharacterState.listening,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.speaker.title,
                      style: TextStyle(
                        color: c.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      node.line,
                      key: ValueKey('story-line-${run.cursor}'),
                      style: TextStyle(
                        color: c.text,
                        fontSize: 15,
                        height: 1.32,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (term != null)
            Row(
              children: [
                Expanded(
                  child: AdaptiveTerm(
                    key: const Key('story-term'),
                    language: widget.language,
                    entry: term,
                    labelOverride: englishOnly
                        ? term.english
                        : widget.language.mode == ImmersionMode.beginner
                        ? '${term.russian} · ${term.english}'
                        : '${term.english} · ${term.russian}',
                    style: TextStyle(color: c.accent, fontSize: 16),
                  ),
                ),
                IconButton(
                  key: const Key('story-audio'),
                  tooltip: 'Послушать фразу',
                  color: c.accent,
                  icon: const Icon(Icons.volume_up_outlined),
                  onPressed: () => unawaited(
                    widget.language.audio.speak(
                      term.english,
                      locale: 'en-US',
                      character: node.speaker.name,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String? _sentence(StoryTask task) =>
      RegExp(r'«([^»]*___[^»]*)»').firstMatch(task.prompt)?.group(1);

  List<Widget> practice(StoryPractice node, StoryRun run, FlightPalette c) {
    final task = node.tasks[run.variant];
    final sentence = _sentence(task);
    final rule = widget.language.snapshot.of(
      KnowledgeCatalog.skills[node.focus]!,
    );
    final showRules = run.assisted || rule.stage() == KnowledgeStage.introduced;
    return [
      const SizedBox(height: 14),
      if (sentence != null) ...[
        gap(task, sentence, c),
        const SizedBox(height: 12),
      ],
      if (task.format == StoryFormat.order)
        wordBoard(task, run, c)
      else
        for (final (i, choice) in task.options.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FlightControl(
              key: Key('story-option-$i'),
              label: choice.text,
              description: run.assisted ? choice.translation : null,
              selected: selection == i,
              onTap: busy
                  ? null
                  : () {
                      unawaited(widget.language.audio.play(SoundEffect.tap));
                      setState(() => selection = selection == i ? null : i);
                    },
            ),
          ),
      if (showRules) ...[const SizedBox(height: 12), rulePanel(node, c)],
      if (run.assisted)
        FlightControl(
          key: const Key('story-example'),
          label: 'Передать по образцу',
          style: FlightControlStyle.quiet,
          onTap: busy ? null : () => move(StoryMove.example),
        ),
    ];
  }

  Widget rulePanel(StoryPractice node, FlightPalette c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.inset,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          node.rule,
          style: TextStyle(color: c.text, fontSize: 14, height: 1.32),
        ),
        const SizedBox(height: 6),
        Text(
          node.example,
          style: TextStyle(
            color: c.accent,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget gap(StoryTask task, String sentence, FlightPalette c) {
    final parts = sentence.split('___');
    final answer = selection == null ? null : task.options[selection!].text;
    final annotation = task.prompt.split('»').last.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.inset,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: parts.first),
                TextSpan(
                  text: answer ?? '_____',
                  style: TextStyle(
                    color: c.accent,
                    backgroundColor: c.selected,
                    decoration: TextDecoration.underline,
                    decorationThickness: 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: parts.last),
              ],
            ),
            key: const Key('story-gap'),
            style: TextStyle(color: c.text, fontSize: 22, height: 1.37),
          ),
          if (annotation.length > 2)
            Text(
              annotation,
              style: TextStyle(color: c.secondary, fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget wordBoard(StoryTask task, StoryRun run, FlightPalette c) =>
      StoryWordBoard(
        tokens: task.tokens,
        draft: run.draft,
        seed: '${widget.scene.id}:${run.cursor}:${run.variant}',
        enabled: !busy,
        onMove: (i) => move(StoryMove.token, i),
      );

  Widget feedback(
    StoryPractice node,
    StoryRun run,
    String answer,
    StoryVerdict verdict,
    FlightPalette c,
  ) {
    final task = node.tasks[run.variant];
    final correct = verdict == StoryVerdict.accepted;
    final sentence =
        _sentence(
          task,
        )?.replaceAll('___', correct ? answer : task.answers.first) ??
        (correct ? answer : task.answers.first);
    final explanation = task.options
        .where((o) => o.text == answer)
        .firstOrNull
        ?.translation;
    final translated = correct && task.format == StoryFormat.order
        ? RegExp(r'«([^»]+)»').firstMatch(task.prompt)?.group(1)
        : explanation;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: Key(correct ? 'story-correct' : 'story-error'),
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: correct ? c.selected : c.warningSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!correct) ...[
              Text(
                explanation == null
                    ? orderExplanation(answer, task.answers.first)
                    : '«$answer» здесь означает: $explanation.',
                style: TextStyle(
                  color: c.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                node.rule,
                style: TextStyle(color: c.text, fontSize: 15, height: 1.28),
              ),
              const SizedBox(height: 8),
            ],
            Text(sentence, style: _heading(c, 19)),
            if (correct && translated != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  translated,
                  style: TextStyle(color: c.secondary, fontSize: 15),
                ),
              ),
            if (!correct)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  node.example,
                  style: TextStyle(color: c.warning, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String orderExplanation(String answer, String expected) {
    final actual = normalizeAnswer(answer).split(' ');
    final target = normalizeAnswer(expected).split(' ');
    for (var i = 0; i < target.length; i++) {
      if (i == actual.length) {
        return 'После «${actual.last}» добавь «${target[i]}».';
      }
      if (actual[i] != target[i]) {
        return 'На месте ${i + 1} нужно «${target[i]}». Сейчас там «${actual[i]}».';
      }
    }
    return 'Фраза заканчивается словом «${target.last}». Убери лишние слова.';
  }

  Widget footer(StoryNode node, StoryRun run, FlightPalette c) {
    final result = outcome;
    Widget primary(String key, String label, VoidCallback? action) =>
        FlightControl(
          key: Key(key),
          label: label,
          style: FlightControlStyle.primary,
          onTap: busy ? null : action,
        );
    Widget control;
    if (result != null) {
      final correct = result.verdict == StoryVerdict.accepted;
      control = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            correct ? 'Реплика принята' : 'Можно исправить',
            key: const Key('story-result-status'),
            style: TextStyle(
              color: correct ? c.accent : c.warning,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          primary('story-continue', correct ? 'Продолжить' : 'Исправить', () {
            setState(() => outcome = null);
            rewind();
          }),
        ],
      );
    } else if (run.finished) {
      control = primary(
        'story-done',
        'Закрыть журнал связи',
        () => Navigator.pop(context),
      );
    } else if (node is StoryLine || node is StoryTrustLine) {
      control = primary(
        'story-next',
        node.targets.isEmpty ? 'Завершить разговор' : 'Дальше',
        () => move(StoryMove.next),
      );
    } else if (node is StoryPractice) {
      final task = node.tasks[run.variant];
      final order = task.format == StoryFormat.order;
      final ready = order ? run.draft.isNotEmpty : selection != null;
      control = Row(
        children: [
          if (!run.assisted) ...[
            IconButton(
              key: const Key('story-help'),
              tooltip: 'Объяснение и перевод',
              color: c.accent,
              icon: const Icon(Icons.translate),
              onPressed: busy
                  ? null
                  : () async {
                      await move(StoryMove.help);
                      if (mounted &&
                          scroll.hasClients &&
                          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                        scroll.jumpTo(scroll.position.maxScrollExtent);
                      }
                    },
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: primary(
              'story-submit',
              'Проверить',
              ready
                  ? () => move(
                      StoryMove.submit,
                      order ? null : task.options[selection!].text,
                    )
                  : null,
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
    final fill = result == null
        ? c.surface
        : result.verdict == StoryVerdict.accepted
        ? c.selected
        : c.warningSurface;
    return Container(
      key: const Key('story-footer'),
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
      decoration: BoxDecoration(
        color: fill,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SizedBox(width: double.infinity, child: control),
    );
  }
}

class StoryWordBoard extends StatelessWidget {
  const StoryWordBoard({
    super.key,
    required this.tokens,
    required this.draft,
    required this.seed,
    required this.onMove,
    this.enabled = true,
  });
  final List<String> tokens;
  final List<int> draft;
  final String seed;
  final ValueChanged<int> onMove;
  final bool enabled;

  List<int> get bank {
    final stable = seed.codeUnits.fold<int>(
      413,
      (value, unit) => (value * 31 + unit) & 0x7fffffff,
    );
    return List.generate(tokens.length, (i) => i)..shuffle(math.Random(stable));
  }

  @override
  Widget build(BuildContext context) {
    final c = FlightPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final reduced = MediaQuery.disableAnimationsOf(context);
        Widget tile(int i, {required bool picked}) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth - 20),
          child: FlightControl(
            key: Key('story-${picked ? 'draft-token' : 'token'}-$i'),
            label: tokens[i],
            style: FlightControlStyle.tile,
            selected: picked,
            onTap: enabled ? () => onMove(i) : null,
            semanticHint: picked ? 'Вернуть в банк слов' : 'Добавить в ответ',
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Твой ответ',
              style: TextStyle(
                color: c.secondary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              key: const Key('story-draft'),
              width: double.infinity,
              constraints: BoxConstraints(
                minHeight: math.max(
                  122,
                  MediaQuery.textScalerOf(context).scale(17) * 2.4 + 79,
                ),
              ),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: c.inset,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.control),
              ),
              child: draft.isEmpty
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Собери фразу из слов ниже',
                        style: TextStyle(color: c.secondary, fontSize: 15),
                      ),
                    )
                  : Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final i in draft)
                          TweenAnimationBuilder<double>(
                            key: ValueKey('story-arrival-$i'),
                            tween: Tween(begin: reduced ? 1 : 0, end: 1),
                            duration: reduced
                                ? Duration.zero
                                : const Duration(milliseconds: 135),
                            builder: (_, value, child) => Transform.translate(
                              offset: Offset(0, (1 - value) * 5),
                              child: Opacity(
                                opacity: .62 + .38 * value,
                                child: child,
                              ),
                            ),
                            child: tile(i, picked: true),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              'Банк слов',
              style: TextStyle(
                color: c.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final i in bank)
                  Stack(
                    key: ValueKey('story-bank-slot-$i'),
                    children: [
                      Visibility(
                        visible: !draft.contains(i),
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: tile(i, picked: false),
                      ),
                      if (draft.contains(i))
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: c.inset,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.line),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Нажми слово в ответе, чтобы вернуть его',
              style: TextStyle(color: c.secondary, fontSize: 13),
            ),
          ],
        );
      },
    );
  }
}
