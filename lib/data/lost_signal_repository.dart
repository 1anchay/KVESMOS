import '../domain/lost_signal.dart';
import '../domain/progress.dart';
import '../domain/rewards.dart';
import 'repository.dart';
import 'rewards_repository.dart';

class LostSignalRepository {
  static const storageKey = 'kvesmos.mission.v1:lost_signal';
  final LearningRepository learning;
  LostSignalRepository(this.learning);

  Future<LostSignalState> read() async =>
      LostSignalState.decode(await learning.setting(storageKey));

  Future<void> _answer(String skill, bool correct, List<String> words) async {
    final stableId = 'mission:v1:lost_signal:$skill:correct';
    if (correct && (await learning.allEvents()).any((e) => e.id == stableId)) {
      return;
    }
    final event = learning.event('answer', {
      'session': 'mission:v1:lost_signal',
      'exercise': skill,
      'adventure': LostSignalMission.id,
      'correct': correct,
      'words': words,
    });
    await learning.append(
      correct
          ? LearningEvent(
              id: stableId,
              kind: event.kind,
              occurredAt: event.occurredAt,
              day: event.day,
              data: event.data,
            )
          : event,
    );
  }

  Future<void> _completeOnce() async {
    final completeId = 'mission:v1:lost_signal:complete';
    if (!(await learning.allEvents()).any((e) => e.id == completeId)) {
      final event = learning.event('adventure_complete', {
        'adventure': LostSignalMission.id,
      });
      await learning.append(
        LearningEvent(
          id: completeId,
          kind: event.kind,
          occurredAt: event.occurredAt,
          day: event.day,
          data: event.data,
        ),
      );
    }
    final inventory = Inventory.decode(
      await learning.setting(RewardsRepository.storageKey),
    );
    inventory.grants.putIfAbsent(
      LostSignalMission.rewardId,
      () => const ChestGrant(LostSignalMission.rewardId, 'explorer'),
    );
    await learning.setSetting(RewardsRepository.storageKey, inventory.encode());
  }

  Future<LostSignalState> act(
    int revision,
    String action, {
    String value = '',
  }) => learning.db.transaction(() async {
    var state = await read();
    if (state.revision != revision) return state;
    if (action == 'replay' && state.completed) {
      state = LostSignalState(revision: state.revision);
    } else if (action == 'hint') {
      state.hint = !state.hint;
    } else if (action == 'travel' && state.doorOpen) {
      if (value == 'dock' || value == 'control') state.room = value;
    } else if (!state.completed) {
      switch (action) {
        case 'start' when state.phase == 0:
          state.phase = 1;
          state.feedback = 'Miko: We lost contact with Station Echo.';
        case 'door' when state.phase == 1:
          state.attempts++;
          final correct = value == 'blue';
          await _answer('blue-door', correct, const ['en:blue', 'en:door']);
          if (correct) {
            state.doorOpen = true;
            state.room = 'control';
            state.phase = 2;
            state.feedback = 'The blue door is open. Search the room.';
            state.hint = false;
          } else {
            state.errors.update('blue-door', (n) => n + 1, ifAbsent: () => 1);
            state.feedback = '$value is not blue. Look at the color.';
            state.hint = true;
          }
        case 'collect' when state.phase == 2:
          if (value == 'red_key' || value == 'battery') {
            state.inventory.add(value);
            state.inspected.add(value);
            state.feedback = value == 'red_key'
                ? 'Red key collected.'
                : 'Battery collected.';
            if (state.inventory.containsAll(const ['red_key', 'battery'])) {
              state.phase = 3;
              state.feedback = 'Miko: Do you have the battery?';
            }
          } else {
            state.inspected.add(value);
            state.errors.update('search', (n) => n + 1, ifAbsent: () => 1);
            state.feedback = 'Nothing useful here. Keep looking.';
          }
        case 'reply' when state.phase == 3:
          state.attempts++;
          final correct = value == 'Yes, I have the battery.';
          await _answer('have-battery', correct, const [
            'en:have',
            'en:battery',
          ]);
          if (correct) {
            state.phase = 4;
            state.feedback = 'Miko: Good. Put it in the power unit.';
            state.hint = false;
          } else {
            state.errors.update(
              'have-battery',
              (n) => n + 1,
              ifAbsent: () => 1,
            );
            state.feedback = 'Check your inventory. You have the battery.';
            state.hint = true;
          }
        case 'install' when state.phase == 4:
          if (!state.inventory.contains('battery') ||
              !state.inventory.contains('red_key')) {
            state.feedback = 'The unit is locked. Find both items first.';
          } else {
            state.inventory.remove('battery');
            state.batteryInstalled = true;
            state.phase = 5;
            state.feedback = 'Battery installed. The control panel is active.';
            state.hint = false;
          }
        case 'button' when state.phase == 5:
          state.attempts++;
          final correct = value == 'green';
          await _answer('green-button', correct, const [
            'en:green',
            'en:button',
          ]);
          if (correct) {
            state.powered = true;
            state.completed = true;
            state.phase = 6;
            state.feedback = 'Station Echo is online. Mission complete!';
            state.hint = false;
            await _completeOnce();
          } else {
            state.errors.update(
              'green-button',
              (n) => n + 1,
              ifAbsent: () => 1,
            );
            state.feedback = '$value is not green. Read the instruction again.';
            state.hint = true;
          }
        default:
          return state;
      }
    } else {
      return state;
    }
    state.revision++;
    await learning.setSetting(storageKey, state.encode());
    return state;
  });
}
