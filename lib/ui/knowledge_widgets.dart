import 'dart:async';

import 'package:flutter/material.dart';

import '../data/knowledge_repository.dart';
import '../domain/knowledge.dart';
import '../services/learning_audio.dart';

/// A screen can keep this context alive while a journal or translation is open.
class LanguageContext extends ChangeNotifier {
  LanguageContext(this.repository, this.audio);
  final KnowledgeRepository repository;
  final LearningAudio audio;
  KnowledgeSnapshot snapshot = KnowledgeSnapshot(const {});
  ImmersionMode mode = ImmersionMode.adaptive;
  bool _closed = false;
  int _generation = 0;
  final _translationShownAt = <String, DateTime>{};

  void noteTranslation(LexiconEntry entry) =>
      _translationShownAt[entry.skill.id] = repository.learning.now();

  bool recentlyHelped(LexiconEntry entry) {
    final when = _translationShownAt[entry.skill.id];
    return when != null &&
        repository.learning.now().difference(when) < const Duration(minutes: 2);
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final snapshot = await repository.read();
    final mode = await repository.mode();
    if (_closed || generation != _generation) return;
    this.snapshot = snapshot;
    this.mode = mode;
    notifyListeners();
  }

  Future<void> pronounce(LexiconEntry term) =>
      audio.speak(term.english, locale: 'en-US', character: term.voice);

  Future<void> encounter(LexiconEntry entry, String context) async {
    try {
      await repository.encounter(entry.skill, context);
      await refresh();
    } catch (_) {
      // The local translation remains available even if a visit can't be logged.
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}

/// Independent hit target. Object interaction belongs to its sibling widget.
class AdaptiveTerm extends StatelessWidget {
  const AdaptiveTerm({
    super.key,
    required this.language,
    required this.entry,
    this.translation,
    this.labelOverride,
    this.style,
    this.compact = false,
  });
  final LanguageContext language;
  final LexiconEntry entry;
  final String? translation;
  final String? labelOverride;
  final TextStyle? style;
  final bool compact;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: language,
    builder: (context, _) {
      final state = language.snapshot.of(entry.skill);
      final label =
          labelOverride ??
          state.label(entry, language.mode, translation: translation);
      return Semantics(
        button: true,
        label: '$label, открыть перевод',
        onTap: () => showTerm(context, language, entry),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(8),
            onTap: () => showTerm(context, language, entry),
            child: ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 2 : 8,
                  vertical: compact ? 3 : 8,
                ),
                child: Text(
                  label,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  textAlign: compact ? TextAlign.center : null,
                  textScaler: compact
                      ? TextScaler.linear(
                          MediaQuery.textScalerOf(
                            context,
                          ).scale(1).clamp(1, 1.15),
                        )
                      : null,
                  style: (style ?? DefaultTextStyle.of(context).style).copyWith(
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showTerm(
  BuildContext context,
  LanguageContext language,
  LexiconEntry term,
) {
  language.noteTranslation(term);
  unawaited(language.encounter(term, 'translation'));
  return _open(context, _TermPanel(language: language, term: term));
}

Future<void> showKnowledgeJournal(
  BuildContext context,
  LanguageContext language,
) => _open(context, _JournalPanel(language: language));

Future<void> showImmersionSettings(
  BuildContext context,
  LanguageContext language,
) => _open(context, _ImmersionSettings(language: language));

Future<void> _open(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => child,
    );

class _TermPanel extends StatefulWidget {
  const _TermPanel({required this.language, required this.term});
  final LanguageContext language;
  final LexiconEntry term;
  @override
  State<_TermPanel> createState() => _TermPanelState();
}

class _TermPanelState extends State<_TermPanel> {
  bool busy = false;
  String? audioProblem;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.language,
    builder: (context, _) {
      final term = widget.term;
      final state = widget.language.snapshot.of(term.skill);
      return _Panel(
        title: term.english,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(term.russian),
            subtitle: Text(term.ipa),
            trailing: IconButton(
              key: const Key('term-audio'),
              tooltip: 'Послушать произношение',
              icon: const Icon(Icons.volume_up_outlined),
              onPressed: () async {
                final heard = await widget.language.audio.speak(
                  term.english,
                  locale: 'en-US',
                  character: term.voice,
                );
                if (mounted) {
                  setState(
                    () => audioProblem = heard
                        ? null
                        : widget.language.audio.lastProblem ??
                              'Аудио недоступно.',
                  );
                }
              },
            ),
          ),
          if (audioProblem != null) Text(audioProblem!),
          Text(term.example, style: Theme.of(context).textTheme.titleMedium),
          Text(term.exampleRu),
          const SizedBox(height: 12),
          Text(
            state.firstSeen == null
                ? 'Ещё нет учебных наблюдений'
                : state.stage().label,
          ),
          if (state.firstSeen != null)
            Text(
              'Самостоятельных ответов: ${state.independent} · с подсказкой: ${state.assisted}',
            ),
          TextButton.icon(
            key: const Key('term-favorite'),
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await widget.language.repository.encounter(
                        term.skill,
                        'translation',
                        onlyIfNew: true,
                      );
                      await widget.language.repository.favorite(
                        term.skill,
                        !state.favorite,
                      );
                      await widget.language.refresh();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Не удалось изменить избранное.'),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            icon: Icon(state.favorite ? Icons.star : Icons.star_border),
            label: Text(
              state.favorite ? 'Убрать из избранного' : 'В избранное',
            ),
          ),
          if (state.firstSeen != null)
            OutlinedButton(
              onPressed: () => _open(
                context,
                _RecallPanel(language: widget.language, term: term),
              ),
              child: const Text('Вспомнить слово или фразу'),
            ),
        ],
      );
    },
  );
}

enum _JournalFilter {
  all('Все'),
  familiar('Изученные'),
  recent('Недавние'),
  difficult('Сложные'),
  favorites('Избранное');

  const _JournalFilter(this.label);
  final String label;
}

class _JournalPanel extends StatefulWidget {
  const _JournalPanel({required this.language});
  final LanguageContext language;
  @override
  State<_JournalPanel> createState() => _JournalPanelState();
}

class _JournalPanelState extends State<_JournalPanel> {
  String query = '';
  _JournalFilter filter = _JournalFilter.all;
  KnowledgeKind? category;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.language,
    builder: (context, _) {
      final now = widget.language.repository.learning.now();
      final practice = widget.language.snapshot.practice(now);
      final entries = practice.where((s) {
        final entry = KnowledgeCatalog.lexicon[s.skill.id]!;
        return (category == null || s.skill.kind == category) &&
            '${entry.english} ${entry.russian} ${entry.skill.title}'
                .toLowerCase()
                .contains(query) &&
            switch (filter) {
              _JournalFilter.all => true,
              _JournalFilter.familiar => s.stage() != KnowledgeStage.introduced,
              _JournalFilter.recent => s.lastSeen!.isAfter(
                now.subtract(const Duration(days: 7)),
              ),
              _JournalFilter.difficult => s.difficult,
              _JournalFilter.favorites => s.favorite,
            };
      }).toList();
      if (filter == _JournalFilter.recent) {
        entries.sort((a, b) => b.lastSeen!.compareTo(a.lastSeen!));
      }
      return _Panel(
        title: 'Бортовой словарь',
        children: [
          TextField(
            key: const Key('journal-search'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Поиск по-русски или по-английски',
            ),
            onChanged: (value) =>
                setState(() => query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final value in _JournalFilter.values)
                ChoiceChip(
                  selected: filter == value,
                  label: Text(value.label),
                  onSelected: (_) => setState(() => filter = value),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                selected: category == KnowledgeKind.word,
                label: const Text('Слова'),
                onSelected: (on) =>
                    setState(() => category = on ? KnowledgeKind.word : null),
              ),
              ChoiceChip(
                selected: category == KnowledgeKind.phrase,
                label: const Text('Фразы'),
                onSelected: (on) =>
                    setState(() => category = on ? KnowledgeKind.phrase : null),
              ),
            ],
          ),
          if (practice.isNotEmpty)
            FilledButton.icon(
              key: const Key('journal-practice'),
              onPressed: () => _open(
                context,
                _RecallPanel(
                  language: widget.language,
                  term: KnowledgeCatalog.lexicon[practice.first.skill.id]!,
                ),
              ),
              icon: const Icon(Icons.replay),
              label: const Text('Персональное повторение'),
            ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                practice.isEmpty
                    ? 'Слова появятся после знакомства с ними на корабле.'
                    : 'В этой подборке пока нет слов.',
              ),
            ),
          for (final s in entries)
            ListTile(
              key: ValueKey('journal-${s.skill.id}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(s.favorite ? Icons.star : Icons.translate),
              title: Text(
                s.label(
                  KnowledgeCatalog.lexicon[s.skill.id]!,
                  widget.language.mode,
                ),
              ),
              subtitle: Text(s.stage().label),
              onTap: () => showTerm(
                context,
                widget.language,
                KnowledgeCatalog.lexicon[s.skill.id]!,
              ),
            ),
          TextButton.icon(
            onPressed: () => showImmersionSettings(context, widget.language),
            icon: const Icon(Icons.tune),
            label: const Text('Режим погружения'),
          ),
        ],
      );
    },
  );
}

class _ImmersionSettings extends StatefulWidget {
  const _ImmersionSettings({required this.language});
  final LanguageContext language;
  @override
  State<_ImmersionSettings> createState() => _ImmersionSettingsState();
}

class _ImmersionSettingsState extends State<_ImmersionSettings> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.language,
    builder: (context, _) => _Panel(
      title: 'Режим погружения',
      children: [
        for (final mode in ImmersionMode.values)
          ListTile(
            key: ValueKey('immersion-${mode.name}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              widget.language.mode == mode
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(mode.label),
            subtitle: Text(switch (mode) {
              ImmersionMode.beginner =>
                'Русский на первом месте. Английский рядом.',
              ImmersionMode.adaptive =>
                'Перевод по нажатию после самостоятельного воспроизведения и повторения в разные дни.',
              ImmersionMode.extended =>
                'Для перевода по нажатию достаточно устойчивого узнавания в разные дни.',
            }),
            onTap: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await widget.language.repository.setMode(mode);
                      await widget.language.refresh();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Не удалось сохранить настройку.'),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
          ),
      ],
    ),
  );
}

class _RecallPanel extends StatefulWidget {
  const _RecallPanel({required this.language, required this.term});
  final LanguageContext language;
  final LexiconEntry term;
  @override
  State<_RecallPanel> createState() => _RecallPanelState();
}

class _RecallPanelState extends State<_RecallPanel> {
  final answer = TextEditingController();
  bool hint = false, busy = false, done = false;
  String? feedback;
  @override
  void dispose() {
    answer.dispose();
    super.dispose();
  }

  Future<void> confirm() async {
    if (busy || done || answer.text.trim().isEmpty) return;
    setState(() => busy = true);
    final correct = widget.term.matches(answer.text);
    final assisted = hint || widget.language.recentlyHelped(widget.term);
    try {
      await widget.language.repository.check(
        widget.term.skill,
        context: 'journal-recall',
        check: KnowledgeCheck.recall,
        correct: correct,
        assisted: assisted,
        error: correct ? null : KnowledgeError.form,
      );
      await widget.language.refresh();
      if (mounted) {
        setState(() {
          done = true;
          feedback = correct
              ? (assisted
                    ? 'Верно. Записано как ответ с подсказкой.'
                    : 'Самостоятельный ответ записан.')
              : 'В этом задании нужно вспомнить запись из словаря. Сверь её ниже.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => feedback = 'Не удалось сохранить ответ. Попробуй ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Вспомни запись',
    children: [
      Text('Напиши по-английски «${widget.term.russian}» так, как в словаре.'),
      const SizedBox(height: 8),
      TextField(
        key: const Key('knowledge-answer'),
        controller: answer,
        enabled: !done && !busy,
        autocorrect: false,
        decoration: const InputDecoration(labelText: 'Ответ'),
        onSubmitted: (_) => confirm(),
      ),
      if (hint || done)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(widget.term.english),
          trailing: IconButton(
            tooltip: 'Послушать произношение',
            icon: const Icon(Icons.volume_up_outlined),
            onPressed: () => unawaited(widget.language.pronounce(widget.term)),
          ),
        ),
      if (feedback != null)
        Text(feedback!, key: const Key('knowledge-feedback')),
      if (!done) ...[
        TextButton(
          onPressed: hint || busy ? null : () => setState(() => hint = true),
          child: const Text('Показать запись'),
        ),
        FilledButton(
          key: const Key('knowledge-check'),
          onPressed: busy ? null : confirm,
          child: const Text('Проверить'),
        ),
      ],
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    ),
  );
}
