import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/lost_signal_repository.dart';
import 'package:orbitwords/data/rewards_repository.dart';
import 'package:orbitwords/domain/lost_signal.dart';
import 'package:orbitwords/domain/rewards.dart';
import 'package:orbitwords/services/recorded_speech.dart';
import 'support.dart';

void main() {
  setUpAll(setupSqlite);

  test('Lost Signal persists world state and rewards only once', () async {
    final learning = memoryRepository();
    final mission = LostSignalRepository(learning);
    var state = await mission.read();

    Future<void> act(String action, [String value = '']) async {
      state = await mission.act(state.revision, action, value: value);
    }

    await act('start');
    await act('door', 'red');
    expect(state.phase, 1);
    expect(state.errors['blue-door'], 1);
    await act('door', 'blue');
    expect(state.room, 'control');
    expect(state.doorOpen, true);

    await act('collect', 'blue_key');
    await act('collect', 'red_key');
    expect(state.inventory, {'red_key'});
    await act('collect', 'battery');
    expect(state.phase, 3);
    expect(state.inventory, {'red_key', 'battery'});

    await act('reply', 'No, I don’t have the battery.');
    expect(state.phase, 3);
    await act('reply', 'Yes, I have the battery.');
    await act('install');
    expect(state.batteryInstalled, true);
    expect(state.inventory, {'red_key'});
    await act('button', 'red');
    expect(state.completed, false);
    await act('button', 'green');
    expect(state.completed, true);
    expect(state.powered, true);

    final saved = await mission.read();
    expect(saved.encode(), state.encode());
    final firstXp = (await learning.progress()).xp;
    expect(firstXp, 30);
    var inventory = Inventory.decode(
      await learning.setting(RewardsRepository.storageKey),
    );
    expect(inventory.grants.keys, contains(LostSignalMission.rewardId));
    expect(
      inventory.grants.keys.where((id) => id == LostSignalMission.rewardId),
      hasLength(1),
    );

    await act('replay');
    await act('start');
    await act('door', 'blue');
    await act('collect', 'red_key');
    await act('collect', 'battery');
    await act('reply', 'Yes, I have the battery.');
    await act('install');
    await act('button', 'green');
    expect((await learning.progress()).xp, firstXp);
    inventory = Inventory.decode(
      await learning.setting(RewardsRepository.storageKey),
    );
    expect(inventory.grants, hasLength(1));
    expect(
      (await learning.allEvents()).where(
        (event) => event.id == 'mission:v1:lost_signal:complete',
      ),
      hasLength(1),
    );
    await learning.db.close();
  });

  test('every mission instruction has a bundled offline recording', () {
    final catalog = RecordedSpeechCatalog.decode(
      File('assets/audio/voices/manifest.json').readAsStringSync(),
    );
    for (final text in [
      'We lost contact with Station Echo. Let’s go.',
      ...LostSignalMission.objectives.skip(1),
    ]) {
      final recording = catalog.find('miko', 'en-US', text);
      expect(recording, isNotNull, reason: text);
      expect(File(recording!.asset).existsSync(), true, reason: text);
      expect(File(recording.slowAsset!).existsSync(), true, reason: text);
    }
  });
}
