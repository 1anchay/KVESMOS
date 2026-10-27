import 'dart:math';
import '../domain/rewards.dart';
import '../domain/journey.dart';
import '../domain/progress.dart';
import 'repository.dart';

/// Additive, versioned state in the existing Settings table. Schema v1 and all
/// learning rows stay untouched. Every read-modify-write uses a DB transaction.
/// Cosmetic state is local only; it is not uploaded as a learning event.
class RewardsRepository {
  static const storageKey = 'kvesmos.inventory.v1';
  final LearningRepository learning;
  final RewardCatalog catalog;
  final Random random;
  RewardsRepository(this.learning, this.catalog, {Random? random})
    : random = random ?? Random.secure();
  Future<Inventory> read() async =>
      Inventory.decode(await learning.setting(storageKey));
  Future<void> _save(Inventory state) =>
      learning.setSetting(storageKey, state.encode());

  /// Reconciliation also grants earned rewards to users updating from OrbitWords.
  /// A crash after lesson commit is recovered here on the next refresh/start.
  Future<Inventory> reconcile() => learning.db.transaction(() async {
    final state = await read();
    final completed = (await learning.progress()).completed.length;
    var changed = false;
    for (final m in catalog.milestones) {
      final id = m['id'] as String;
      if (completed >= (m['unique_lesson_count'] as int) &&
          !state.grants.containsKey(id)) {
        state.grants[id] = ChestGrant(id, m['chest_id']);
        changed = true;
      }
    }
    if (await learning.setting('kvesmos.expeditions.optin.v1') == 'true') {
      var since = await learning.setting('kvesmos.expeditions.since.v1');
      if (since == null) {
        final now = learning.now();
        final month = DateTime(now.year, now.month, 1);
        final week = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        since = dayKey(month.isBefore(week) ? month : week);
        await learning.setSetting('kvesmos.expeditions.since.v1', since);
      }
      for (final expedition in Expedition.earnedHistory(
        await learning.allEvents(),
        learning.now(),
        since,
      )) {
        if (expedition.complete && !state.grants.containsKey(expedition.id)) {
          state.grants[expedition.id] = ChestGrant(
            expedition.id,
            expedition.chest,
          );
          changed = true;
        }
      }
    }
    if (changed) await _save(state);
    return state;
  });

  Future<Cosmetic?> open(String chestInstanceId) =>
      learning.db.transaction(() async {
        final state = await read();
        final grant = state.grants[chestInstanceId];
        if (grant == null) throw StateError('Этот сундук ещё не получен.');
        if (grant.itemId != null) return catalog.item(grant.itemId!);
        final item = catalog.draw(grant.kind, state.owned, random);
        if (item == null) return null;
        state.grants[grant.id] = ChestGrant(grant.id, grant.kind, item.id);
        await _save(state);
        return item;
      });

  Future<Inventory> equip(String slot, String? itemId) =>
      learning.db.transaction(() async {
        final state = await read();
        if (itemId == null) {
          state.equipped.remove(slot);
        } else {
          final item = catalog.item(itemId);
          if (item.slot != slot || !state.owned.contains(itemId)) {
            throw StateError('Сначала получите этот предмет из сундука.');
          }
          state.equipped[slot] = itemId;
        }
        await _save(state);
        return state;
      });
}
