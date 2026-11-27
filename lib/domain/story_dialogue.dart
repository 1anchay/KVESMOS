import 'course.dart';
import 'first_flight.dart';
import 'knowledge.dart';

enum StorySpeaker {
  orbi('Орби'),
  miko('Мико'),
  pixie('Пикси');

  const StorySpeaker(this.title);
  final String title;
}

enum StoryFormat { answer, reaction, order, word, phrase }

enum StoryVerdict { accepted, incorrect, unsupported }

class StoryOption {
  const StoryOption(this.text, this.translation);
  final String text, translation;
}

class StoryTask {
  const StoryTask(
    this.format,
    this.prompt,
    this.answers, {
    this.options = const [],
    this.tokens = const [],
    this.required = const {},
  });

  final StoryFormat format;
  final String prompt;
  final List<String> answers, tokens;
  final List<StoryOption> options;
  final Map<String, KnowledgeStage> required;

  bool available(KnowledgeSnapshot knowledge) => required.entries.every(
    (e) =>
        knowledge.of(KnowledgeCatalog.skills[e.key]!).stage().index >=
        e.value.index,
  );

  String joined(List<int> draft) => draft.map((i) => tokens[i]).join(' ');

  StoryVerdict evaluate(String value) {
    final normalized = normalizeAnswer(value);
    if (normalized.isEmpty) return StoryVerdict.unsupported;
    if (answers.any((answer) => normalizeAnswer(answer) == normalized)) {
      return StoryVerdict.accepted;
    }
    return format == StoryFormat.order ||
            options.any((item) => normalizeAnswer(item.text) == normalized)
        ? StoryVerdict.incorrect
        : StoryVerdict.unsupported;
  }
}

sealed class StoryNode {
  const StoryNode(this.speaker, this.line);
  final StorySpeaker speaker;
  final String line;
  Iterable<String> get targets;
}

class StoryLine extends StoryNode {
  const StoryLine(
    super.speaker,
    super.line, {
    this.next,
    this.term,
    this.sentenceSkills = const [],
  });
  final String? next, term;
  final List<String> sentenceSkills;
  @override
  Iterable<String> get targets => [?next];
}

class StoryPractice extends StoryNode {
  const StoryPractice(
    super.speaker,
    super.line, {
    required this.next,
    required this.rule,
    required this.example,
    required this.tasks,
    required this.focus,
    this.proves = const [],
    this.transfer = false,
  });
  final String next, rule, example, focus;
  final List<StoryTask> tasks;
  final List<String> proves;
  final bool transfer;
  @override
  Iterable<String> get targets => [next];

  int variant(KnowledgeSnapshot knowledge) =>
      tasks.lastIndexWhere((t) => t.available(knowledge));
}

class StoryChoice {
  const StoryChoice(
    this.id,
    this.label,
    this.next, {
    this.trust,
    this.requiresTrust,
  });
  final String id, label, next;
  final StorySpeaker? trust, requiresTrust;
}

class StoryDecision extends StoryNode {
  const StoryDecision(super.speaker, super.line, this.choices);
  final List<StoryChoice> choices;
  @override
  Iterable<String> get targets => choices.map((choice) => choice.next);
}

class StoryTrustLine extends StoryNode {
  const StoryTrustLine(
    super.speaker,
    super.line, {
    required this.who,
    required this.trusted,
    required this.standard,
  });
  final StorySpeaker who;
  final String trusted, standard;
  @override
  Iterable<String> get targets => [trusted, standard];
}

enum StoryCue {
  beforeRepair,
  foundBattery,
  restoredPower,
  launchDebrief,
  beforeFishing,
  afterFishing;

  bool reached(FirstFlight flight) => switch (this) {
    beforeRepair => flight.unlocked,
    foundBattery =>
      flight.inventory.contains(FlightItem.battery) || flight.charged,
    restoredPower => flight.powered,
    launchDebrief => flight.complete,
    beforeFishing => flight.complete,
    afterFishing => false,
  };
}

class StoryScene {
  const StoryScene(this.id, this.title, this.cue, this.start, this.nodes);
  final String id, title, start;
  final StoryCue cue;
  final Map<String, StoryNode> nodes;

  void validate() {
    final reached = <String>{};
    final active = <String>{};
    void visit(String id) {
      if (active.contains(id)) throw FormatException('Диалог $this: цикл $id');
      final node = nodes[id];
      if (node == null) throw FormatException('Нет реплики $id');
      if (!reached.add(id)) return;
      active.add(id);
      if (node.line.trim().isEmpty) throw FormatException('Пустая реплика $id');
      if (node is StoryLine &&
          (node.term != null &&
                  !KnowledgeCatalog.lexicon.containsKey(node.term) ||
              !node.sentenceSkills.every(
                KnowledgeCatalog.skills.containsKey,
              ))) {
        throw FormatException('Неизвестная лексика реплики $id');
      }
      if (node is StoryPractice) {
        if (node.tasks.isEmpty ||
            node.tasks.first.required.isNotEmpty ||
            node.rule.isEmpty ||
            node.example.isEmpty ||
            ![
              node.focus,
              ...node.proves,
            ].every(KnowledgeCatalog.skills.containsKey)) {
          throw FormatException('Нет доступного объяснения или навыка $id');
        }
        for (final task in node.tasks) {
          if (task.answers.isEmpty ||
              !task.required.keys.every(KnowledgeCatalog.skills.containsKey) ||
              (task.format == StoryFormat.order
                  ? !task.answers.every(
                      (answer) => _containsTokens(task.tokens, answer),
                    )
                  : !task.options.any(
                      (option) =>
                          task.evaluate(option.text) == StoryVerdict.accepted,
                    ))) {
            throw FormatException('Некорректное упражнение $id');
          }
        }
      }
      if (node is StoryDecision &&
          (node.choices.length < 2 ||
              node.choices.map((c) => c.id).toSet().length !=
                  node.choices.length ||
              !node.choices.any((c) => c.requiresTrust == null))) {
        throw FormatException('Нет доступного сюжетного выбора $id');
      }
      if (node.targets.isEmpty && node is! StoryLine) {
        throw FormatException('Нет финала $id');
      }
      for (final next in node.targets) {
        visit(next);
      }
      active.remove(id);
    }

    visit(start);
    if (reached.length != nodes.length) {
      throw FormatException('Недоступная реплика в $id');
    }
  }

  static bool _containsTokens(List<String> tokens, String answer) {
    final remaining = tokens.map(normalizeAnswer).toList();
    return answer
        .split(' ')
        .every((word) => remaining.remove(normalizeAnswer(word)));
  }
}
