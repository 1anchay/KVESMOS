import '../domain/missions.dart';
import '../domain/progress.dart';
import '../domain/rewards.dart';
import 'repository.dart';
import 'rewards_repository.dart';

class MissionsRepository {
  static const sinceKey = 'kvesmos.missions.since.v1';
  final LearningRepository learning;
  MissionsRepository(this.learning);

  /// One transaction for activation date, earned grants and their fixed IDs.
  /// Reconcile past completed days too, to recover a crash before reward delivery.
  /// Only today's older work is eligible when missions are first introduced.
  Future<MissionSnapshot> reconcile() => learning.db.transaction(() async {
    final today = dayKey(learning.now());
    var since = await learning.setting(sinceKey);
    if (since == null || today.compareTo(since) < 0) {
      since = today;
      await learning.setSetting(sinceKey, since);
    }
    final history = missionHistory(
      await learning.allEvents(),
      since: since,
      through: today,
    );
    final inventory = Inventory.decode(
      await learning.setting(RewardsRepository.storageKey),
    );
    var changed = false;
    for (final entry in history.entries) {
      for (final mission in DailyMission.all) {
        final id = mission.grantId(entry.key);
        if (entry.value.completed(mission) &&
            !inventory.grants.containsKey(id)) {
          inventory.grants[id] = ChestGrant(id, mission.chest);
          changed = true;
        }
      }
    }
    if (changed) {
      await learning.setSetting(
        RewardsRepository.storageKey,
        inventory.encode(),
      );
    }
    return MissionSnapshot(today, history[today] ?? MissionDay(), inventory);
  });
}
