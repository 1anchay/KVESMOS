import 'dart:async';

import 'package:flutter/material.dart';

import '../data/story_repository.dart';
import '../domain/knowledge.dart';
import '../domain/story_dialogue.dart';
import 'character_moment.dart';
import 'first_flight_art.dart';
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
  showDragHandle: true,
  backgroundColor: flightInk,
  builder: (_) => _StorySheet(scene, repository, language),
);

class _StorySheet extends StatefulWidget {
  const _StorySheet(this.scene, this.repository, this.language);
  final StoryScene scene;
  final StoryRepository repository;
  final LanguageContext language;
  @override
  State<_StorySheet> createState() => _StorySheetState();
}

class _StorySheetState extends State<_StorySheet> {
  StoryView? view;
  bool busy = false;
  String? error;
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

  Future<void> move(StoryMove move, [Object? input]) async {
    if (busy) return;
    final current = view!;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final updated = await widget.repository.move(
        widget.scene,
        current.run.revision,
        move,
        input,
      );
      if (updated.run.cursor != current.run.cursor || updated.verdict != null) {
        await widget.language.refresh();
      }
      if (!mounted) return;
      setState(() {
        view = updated;
        if (updated.verdict == StoryVerdict.unsupported) {
          error =
              'Эту реплику нельзя проверить локально. Выбери ответ или воспользуйся примером.';
        }
      });
      if (updated.run.cursor != current.run.cursor && scroll.hasClients) {
        scroll.jumpTo(0);
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

  @override
  Widget build(BuildContext context) {
    final state = view;
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: .84,
        child: ListenableBuilder(
          listenable: widget.language,
          builder: (context, _) => ListView(
            controller: scroll,
            key: const Key('story-sheet'),
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.scene.title,
                      style: const TextStyle(
                        color: flightMint,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('story-close'),
                    tooltip: 'Закрыть связь',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: flightText),
                  ),
                ],
              ),
              if (state == null && error == null)
                const Center(
                  child: CircularProgressIndicator(color: flightMint),
                ),
              if (state == null && error != null)
                OutlinedButton(onPressed: open, child: Text(error!)),
              if (state != null) ...contents(state),
              if (state != null && error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: flightAmber),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> contents(StoryView state) {
    final run = state.run;
    final node = widget.scene.nodes[run.cursor]!;
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
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IgnorePointer(
            child: SpeakingCharacter(
              audio: widget.language.audio,
              character: node.speaker.name,
              size: 72,
              state: run.wrong
                  ? CharacterState.support
                  : run.finished
                  ? CharacterState.celebration
                  : CharacterState.listening,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.speaker.title,
                  style: const TextStyle(
                    color: flightAmber,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  node.line,
                  key: ValueKey('story-line-${run.cursor}'),
                  style: const TextStyle(
                    color: flightText,
                    fontSize: 17,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (term != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              Expanded(
                child: AdaptiveTerm(
                  key: const Key('story-term'),
                  language: widget.language,
                  entry: term,
                  labelOverride: englishOnly
                      ? term.english
                      : '${term.english} · ${term.russian}',
                  style: const TextStyle(color: flightMint),
                ),
              ),
              IconButton(
                key: const Key('story-audio'),
                tooltip: 'Послушать фразу',
                onPressed: () => unawaited(
                  widget.language.audio.speak(
                    term.english,
                    locale: 'en-US',
                    character: node.speaker.name,
                  ),
                ),
                icon: const Icon(Icons.volume_up_outlined, color: flightMint),
              ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      if (run.finished)
        primary(
          'story-done',
          'Закрыть журнал связи',
          () => Navigator.pop(context),
        )
      else if (node is StoryLine || node is StoryTrustLine)
        primary(
          'story-next',
          node.targets.isEmpty ? 'Завершить разговор' : 'Дальше',
          () => move(StoryMove.next),
        )
      else if (node is StoryDecision) ...[
        for (final choice in node.choices)
          if (choice.requiresTrust == null ||
              state.save.trust(choice.requiresTrust!) > 0)
            option(
              'story-choice-${choice.id}',
              choice.label,
              () => move(StoryMove.choice, choice.id),
            ),
      ] else if (node is StoryPractice)
        ...practice(node, run),
    ];
  }

  List<Widget> practice(StoryPractice node, StoryRun run) {
    final task = node.tasks[run.variant];
    final rule = widget.language.snapshot.of(
      KnowledgeCatalog.skills[node.focus]!,
    );
    return [
      if (run.wrong)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Эта реплика меняет смысл сообщения или его форму. Сверь правило и попробуй ещё раз.',
            key: Key('story-error'),
            style: TextStyle(color: flightAmber),
          ),
        ),
      if (run.assisted || rule.stage() == KnowledgeStage.introduced)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: flightPanel,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                node.rule,
                style: const TextStyle(color: flightText, height: 1.3),
              ),
              const SizedBox(height: 6),
              Text(node.example, style: const TextStyle(color: flightMint)),
            ],
          ),
        ),
      const SizedBox(height: 10),
      Text(
        task.prompt,
        key: ValueKey('story-task-${task.format.name}'),
        style: const TextStyle(
          color: flightText,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 8),
      if (task.format == StoryFormat.order) ...[
        Container(
          key: const Key('story-draft'),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: flightPanel,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (run.draft.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Коснись слов в нужном порядке',
                    style: TextStyle(color: flightText),
                  ),
                ),
              for (final i in run.draft) token(task.tokens[i], i, true),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final (i, text) in task.tokens.indexed)
              if (!run.draft.contains(i)) token(text, i, false),
          ],
        ),
        primary(
          'story-submit',
          'Передать реплику',
          run.draft.isEmpty ? null : () => move(StoryMove.submit),
        ),
      ] else
        for (final (i, choice) in task.options.indexed)
          option(
            'story-option-$i',
            run.assisted
                ? '${choice.text}\n${choice.translation}'
                : choice.text,
            () => move(StoryMove.submit, choice.text),
          ),
      if (run.assisted)
        TextButton(
          key: const Key('story-example'),
          onPressed: busy ? null : () => move(StoryMove.example),
          child: const Text(
            'Передать по образцу',
            style: TextStyle(color: flightMint),
          ),
        )
      else
        TextButton.icon(
          key: const Key('story-help'),
          onPressed: busy ? null : () => move(StoryMove.help),
          icon: const Icon(Icons.translate, color: flightMint),
          label: const Text(
            'Объяснение и перевод',
            style: TextStyle(color: flightMint),
          ),
        ),
    ];
  }

  Widget token(String text, int index, bool selected) => ActionChip(
    key: ValueKey('story-${selected ? 'draft-token' : 'token'}-$index'),
    backgroundColor: selected ? flightMint : flightPanel,
    disabledColor: flightPanel,
    label: Text(
      text,
      style: TextStyle(color: selected ? flightInk : flightText),
    ),
    onPressed: busy ? null : () => move(StoryMove.token, index),
  );

  Widget primary(String id, String label, VoidCallback? callback) =>
      FilledButton(
        key: Key(id),
        style: FilledButton.styleFrom(
          backgroundColor: flightMint,
          foregroundColor: flightInk,
          minimumSize: const Size(0, 48),
        ),
        onPressed: busy ? null : callback,
        child: Text(label),
      );

  Widget option(String id, String label, VoidCallback callback) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: OutlinedButton(
      key: Key(id),
      style: OutlinedButton.styleFrom(
        foregroundColor: flightText,
        side: const BorderSide(color: Color(0xff708c9d)),
        minimumSize: const Size(0, 48),
        alignment: Alignment.centerLeft,
      ),
      onPressed: busy ? null : callback,
      child: Text(label),
    ),
  );
}
