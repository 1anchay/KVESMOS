import '../domain/space_adventures.dart';
import '../domain/progress.dart';
import 'repository.dart';

/// Additive SQLite v1 state. Every action commits before its visual feedback.
class AdventuresRepository {
  final LearningRepository learning;
  AdventuresRepository(this.learning);
  static String key(String id) => 'kvesmos.adventure.v1:$id';
  Future<AdventureState> read(String id) async =>
      AdventureState.decode(await learning.setting(key(id)));
  Future<AdventureState> act(
    SpaceAdventure adventure,
    int revision,
    String action, {
    String value = '',
    double? x,
    double? y,
  }) => learning.db.transaction(() async {
    if (!adventure.unlocked((await learning.progress()).completed)) {
      throw StateError('Сначала пройди отмеченные на карте уроки.');
    }
    var state = await read(adventure.id);
    if (state.revision != revision) return state; // stale tap / second route
    if (action == 'replay' && state.completed) {
      state = AdventureState(revision: state.revision);
    } else if (!state.completed) {
      final step = adventure.steps[state.step];
      switch (action) {
        case 'move':
          state.x = (x ?? state.x).clamp(.08, .92);
          state.y = (y ?? state.y).clamp(.2, .88);
          state.focus = value;
        case 'hint':
          state.hint = !state.hint;
        case 'select':
          state.selection = value;
        case 'tile':
          if (step.options.contains(value) && !state.tiles.contains(value)) {
            state.tiles.add(value);
          }
        case 'clear':
          state.tiles.clear();
        case 'submit':
          if (state.focus != step.target) return state;
          final input = step.action == AdventureAction.assemble
              ? state.tiles.join(' ')
              : value;
          final correct = !step.assessed || input == step.answer;
          state.attempts++;
          if (step.assessed) {
            final successId = 'adventure:v1:${adventure.id}:${step.id}:correct';
            final credited = (await learning.allEvents()).any(
              (e) => e.id == successId,
            );
            // Replaying never farms XP, mastery, daily tasks or error counters.
            if (!credited) {
              final event = learning.event('answer', {
                'session': 'adventure:v1:${adventure.id}',
                'exercise': step.id,
                'adventure': adventure.id,
                'correct': correct,
                'words': step.words,
              });
              await learning.append(
                correct
                    ? LearningEvent(
                        id: successId,
                        kind: event.kind,
                        occurredAt: event.occurredAt,
                        day: event.day,
                        data: event.data,
                      )
                    : event,
              );
            }
          }
          if (correct) {
            state.resolved.add(step.id);
            if (step.action == AdventureAction.inspect &&
                ['book', 'pen', 'bag'].contains(step.target)) {
              state.found.add(step.target);
            }
            if (step.action == AdventureAction.cargo) {
              state.found.remove(step.answer);
            }
            state.step++;
            state.completed = state.step == adventure.steps.length;
            state.dialogue = state.completed
                ? adventure.outcome
                : 'Получилось! Следующий шаг готов.';
            state.focus = '';
            state.selection = '';
            state.tiles.clear();
            state.hint = false;
            if (state.completed) {
              final e = learning.event('adventure_complete', {
                'adventure': adventure.id,
              });
              await learning.append(
                LearningEvent(
                  id: 'adventure:v1:${adventure.id}:complete',
                  kind: e.kind,
                  occurredAt: e.occurredAt,
                  day: e.day,
                  data: e.data,
                ),
              );
            }
          } else {
            state.errors.update(step.id, (n) => n + 1, ifAbsent: () => 1);
            state.dialogue = 'Попробуем ещё. ${step.explanation}';
            state.hint = true;
            state.tiles.clear();
          }
        default:
          return state;
      }
    } else {
      return state;
    }
    state.room =
        adventure.steps[state.step.clamp(0, adventure.steps.length - 1)].room;
    state.revision++;
    await learning.setSetting(key(adventure.id), state.encode());
    return state;
  });
}
