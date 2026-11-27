import 'dart:convert';

import '../domain/flight_story.dart';
import '../domain/fishing_story.dart';
import '../domain/knowledge.dart';
import '../domain/story_dialogue.dart';
import 'first_flight_repository.dart';
import 'fishing_repository.dart';
import 'knowledge_repository.dart';
import 'repository.dart';

enum StoryMove { next, choice, token, help, submit, example }

const _scenes = [...FlightStory.scenes, ...FishingStory.scenes];
final _sceneById = {for (final scene in _scenes) scene.id: scene};

class StoryRun {
  StoryRun(this.path);
  final List<String> path;
  final choices = <String, String>{};
  final draft = <int>[];
  int revision = 0, variant = 0;
  bool assisted = false, wrong = false, finished = false;
  String get cursor => path.last;

  Map<String, Object> toJson() => {
    'path': path,
    'choices': choices,
    'draft': draft,
    'revision': revision,
    'variant': variant,
    'assisted': assisted,
    'wrong': wrong,
    'finished': finished,
  };

  static StoryRun decode(StoryScene scene, Map<String, dynamic> json) {
    final path = List<String>.from(json['path'] as List);
    final run = StoryRun(path)
      ..choices.addAll(Map<String, String>.from(json['choices'] as Map))
      ..draft.addAll(List<int>.from(json['draft'] as List))
      ..revision = json['revision'] as int
      ..variant = json['variant'] as int
      ..assisted = json['assisted'] as bool
      ..wrong = json['wrong'] as bool
      ..finished = json['finished'] as bool;
    if (path.isEmpty ||
        path.first != scene.start ||
        path.length > scene.nodes.length ||
        path.toSet().length != path.length ||
        run.revision < path.length - 1 ||
        run.wrong && !run.assisted) {
      throw const FormatException('Некорректный путь диалога');
    }
    var decisions = 0;
    for (var i = 0; i < path.length - 1; i++) {
      final node = scene.nodes[path[i]];
      final next = path[i + 1];
      if (node == null || !node.targets.contains(next)) {
        throw const FormatException('Нет такого перехода');
      }
      if (node is StoryDecision) {
        decisions++;
        if (!node.choices.any(
          (c) => c.id == run.choices[path[i]] && c.next == next,
        )) {
          throw const FormatException('Выбор не соответствует пути');
        }
      }
    }
    if (decisions != run.choices.length) {
      throw const FormatException('Лишние решения');
    }
    final node = scene.nodes[run.cursor];
    if (node is StoryPractice) {
      if (run.finished ||
          run.variant < 0 ||
          run.variant >= node.tasks.length ||
          run.draft.toSet().length != run.draft.length ||
          run.draft.any(
            (i) => i < 0 || i >= node.tasks[run.variant].tokens.length,
          )) {
        throw const FormatException('Некорректный черновик');
      }
    } else if (node == null ||
        run.variant != 0 ||
        run.assisted ||
        run.wrong ||
        run.draft.isNotEmpty ||
        run.finished && node.targets.isNotEmpty) {
      throw const FormatException('Некорректный конец диалога');
    }
    return run;
  }
}

class StorySave {
  final runs = <String, StoryRun>{};

  int trust(StorySpeaker speaker) =>
      decisions.where((c) => c.trust == speaker).length;

  Iterable<StoryChoice> get decisions sync* {
    for (final entry in runs.entries) {
      final scene = _sceneById[entry.key]!;
      for (final decision in entry.value.choices.entries) {
        final node = scene.nodes[decision.key] as StoryDecision;
        yield node.choices.firstWhere((c) => c.id == decision.value);
      }
    }
  }

  String encode() =>
      jsonEncode({for (final e in runs.entries) e.key: e.value.toJson()});

  factory StorySave.decode(String? raw) {
    final save = StorySave();
    if (raw == null) return save;
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    for (final e in data.entries) {
      final scene = _sceneById[e.key];
      if (scene == null) throw const FormatException('Неизвестная история');
      save.runs[e.key] = StoryRun.decode(
        scene,
        Map<String, dynamic>.from(e.value as Map),
      );
    }
    for (final entry in save.runs.entries) {
      if (!save._supportsPath(_sceneById[entry.key]!, entry.value)) {
        throw const FormatException('Не выполнено условие сюжетной ветки');
      }
    }
    return save;
  }

  StorySave();

  bool _supportsPath(StoryScene scene, StoryRun run) {
    for (var i = 0; i < run.path.length - 1; i++) {
      final id = run.path[i];
      final node = scene.nodes[id];
      if (node is StoryTrustLine &&
          run.path[i + 1] == node.trusted &&
          trust(node.who) == 0) {
        return false;
      }
      if (node is StoryDecision) {
        final choice = node.choices.firstWhere((c) => c.id == run.choices[id]);
        if (choice.requiresTrust case final speaker? when trust(speaker) == 0) {
          return false;
        }
      }
    }
    return true;
  }

  /// Keep the profile's own decision if imports contain different branches.
  void merge(StorySave source) {
    for (final scene in _scenes) {
      final local = runs[scene.id];
      final incoming = source.runs[scene.id];
      if (incoming == null || !_supportsPath(scene, incoming)) continue;
      if (local == null) {
        runs[scene.id] = incoming;
        continue;
      }
      final samePath =
          local.path.length <= incoming.path.length &&
          local.path.indexed.every((p) => p.$2 == incoming.path[p.$1]) &&
          local.choices.entries.every(
            (c) => incoming.choices[c.key] == c.value,
          );
      if (!samePath || local.finished) continue;
      if (incoming.cursor == local.cursor &&
          incoming.variant != local.variant) {
        continue;
      }
      if (incoming.path.length > local.path.length ||
          incoming.finished ||
          incoming.revision > local.revision) {
        if (incoming.cursor == local.cursor &&
            !incoming.finished &&
            incoming.variant == local.variant) {
          // A backup must not turn an already-assisted draft into independent evidence.
          incoming.assisted |= local.assisted;
          incoming.wrong |= local.wrong;
        }
        runs[scene.id] = incoming;
      }
    }
  }
}

typedef StoryView = ({StorySave save, StoryRun run, StoryVerdict? verdict});

class StoryRepository {
  StoryRepository(this.learning) : knowledge = KnowledgeRepository(learning);
  static const storageKey = 'kvesmos.story.flight.v1:ru-en';
  final LearningRepository learning;
  final KnowledgeRepository knowledge;

  Future<StorySave> read() async =>
      StorySave.decode(await learning.setting(storageKey));

  Future<StoryView> open(StoryScene scene) => learning.db.transaction(() async {
    final save = await read();
    final existing = save.runs[scene.id];
    if (existing != null) return (save: save, run: existing, verdict: null);
    if (!await _reached(scene)) {
      throw StateError('Сигнал пока недоступен.');
    }
    final run = save.runs[scene.id] = StoryRun([scene.start]);
    await _prepare(scene, run);
    await learning.setSetting(storageKey, save.encode());
    return (save: save, run: run, verdict: null);
  });

  Future<bool> _reached(StoryScene scene) async {
    final flight = await FirstFlightRepository(learning).read();
    if (scene.cue != StoryCue.afterFishing) return scene.cue.reached(flight);
    if (!flight.complete) return false;
    final fishing = await FishingRepository(learning).read();
    final caught = scene.id == FishingStory.report.id;
    return fishing.reports.keys.any(
      (trip) => fishing.forTrip(trip).isNotEmpty == caught,
    );
  }

  Future<StoryView> move(
    StoryScene scene,
    int revision,
    StoryMove move, [
    Object? input,
  ]) => learning.db.transaction(() async {
    final save = await read();
    final run = save.runs[scene.id];
    if (run == null) throw StateError('Диалог ещё не открыт.');
    StoryView view([StoryVerdict? result]) =>
        (save: save, run: run, verdict: result);
    if (run.revision != revision || run.finished) return view();
    final node = scene.nodes[run.cursor]!;
    String? next;
    StoryVerdict? result;
    switch (move) {
      case StoryMove.next:
        switch (node) {
          case StoryLine(:final next):
            if (next == null) {
              run.finished = true;
            } else {
              await _enter(scene, run, next);
            }
          case StoryTrustLine(:final who, :final trusted, :final standard):
            next = save.trust(who) > 0 ? trusted : standard;
          default:
            return view();
        }
      case StoryMove.choice:
        if (node is! StoryDecision) return view();
        final choice = node.choices
            .where(
              (c) =>
                  c.id == input &&
                  (c.requiresTrust == null || save.trust(c.requiresTrust!) > 0),
            )
            .firstOrNull;
        if (choice == null) return view();
        run.choices[run.cursor] = choice.id;
        next = choice.next;
      case StoryMove.help:
        if (node is! StoryPractice || run.assisted) return view();
        run.assisted = true;
      case StoryMove.token:
        if (node is! StoryPractice ||
            input is! int ||
            input < 0 ||
            input >= node.tasks[run.variant].tokens.length) {
          return view();
        }
        if (!run.draft.remove(input)) run.draft.add(input);
      case StoryMove.submit:
      case StoryMove.example:
        if (node is! StoryPractice) return view();
        final task = node.tasks[run.variant];
        final guided = move == StoryMove.example;
        if (guided && !run.assisted) return view();
        final answer = guided
            ? task.answers.first
            : task.format == StoryFormat.order
            ? task.joined(run.draft)
            : input as String? ?? '';
        result = task.evaluate(answer);
        if (result == StoryVerdict.unsupported) return view(result);
        final correct = result == StoryVerdict.accepted;
        if (correct || !run.wrong) {
          await _evidence(scene, run, node, task, correct);
        }
        if (correct) {
          next = node.next;
        } else {
          run.wrong = true;
          run.assisted = true;
        }
    }
    if (next != null) await _enter(scene, run, next);
    run.revision++;
    await learning.setSetting(storageKey, save.encode());
    return view(result);
  });

  Future<void> _enter(StoryScene scene, StoryRun run, String next) async {
    run.path.add(next);
    run.variant = 0;
    run.draft.clear();
    run.assisted = false;
    run.wrong = false;
    await _prepare(scene, run);
  }

  Future<void> _prepare(StoryScene scene, StoryRun run) async {
    final node = scene.nodes[run.cursor]!;
    if (node is StoryPractice) {
      run.variant = node.variant(await knowledge.read());
      await knowledge.restoreEncounters([
        for (final id in {node.focus, ...node.proves})
          KnowledgeCatalog.skills[id]!,
      ], 'story:${scene.id}:${run.cursor}');
    } else if (node is StoryLine && node.term != null) {
      await knowledge.encounter(
        KnowledgeCatalog.skills[node.term]!,
        'story:${scene.id}:${run.cursor}',
      );
    }
  }

  Future<void> _evidence(
    StoryScene scene,
    StoryRun run,
    StoryPractice node,
    StoryTask task,
    bool correct,
  ) async {
    final observation = switch (task.format) {
      StoryFormat.answer ||
      StoryFormat.reaction ||
      StoryFormat.word ||
      StoryFormat.phrase => KnowledgeCheck.recognition,
      StoryFormat.order =>
        node.transfer ? KnowledgeCheck.transfer : KnowledgeCheck.recall,
    };
    for (final id in {node.focus, if (correct) ...node.proves}) {
      await knowledge.check(
        KnowledgeCatalog.skills[id]!,
        context: 'story:${scene.id}:${run.cursor}',
        check: observation,
        correct: correct,
        assisted: run.assisted,
        recordKey: 'story-v1:${scene.id}:${run.cursor}:$correct',
        error: correct
            ? null
            : task.format == StoryFormat.answer ||
                  task.format == StoryFormat.reaction
            ? KnowledgeError.meaning
            : KnowledgeError.grammar,
      );
    }
  }
}
