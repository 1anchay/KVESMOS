import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/domain/progress.dart';
import 'package:orbitwords/services/sync.dart';
import 'support.dart';

class FakeRemote implements SyncRemote {
  @override
  String? userId = 'user-a';
  bool fail = false, loseAcknowledgment = false;
  final Map<String, LearningEvent> events = {};
  @override
  Future<void> push(List<LearningEvent> incoming) async {
    if (fail) throw Exception('offline');
    for (final e in incoming) {
      events.putIfAbsent(e.id, () => e);
    }
    if (loseAcknowledgment) throw Exception('lost response');
  }

  @override
  Future<List<LearningEvent>> pull() async {
    if (fail) throw Exception('offline');
    return events.values.toList();
  }
}

void main() {
  setUpAll(setupSqlite);
  test('offline failures retain durable queue and retry converges', () async {
    final r = memoryRepository();
    addTearDown(r.db.close);
    await r.initialize();
    await r.review(r.vocabulary.values.first, 'hello');
    final remote = FakeRemote()..fail = true;
    final sync = SyncService(r, remote);
    await expectLater(sync.run(), throwsException);
    expect(await r.pending(), hasLength(1));
    expect(sync.busy, isFalse);
    remote.fail = false;
    await sync.run();
    expect(await r.pending(), isEmpty);
    expect(remote.events, hasLength(1));
    expect(sync.status, 'Синхронизировано');
  });
  test(
    'server commit followed by lost response retries without duplicate reward',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      await r.review(r.vocabulary.values.first, 'hello');
      final remote = FakeRemote()..loseAcknowledgment = true;
      final sync = SyncService(r, remote);
      await expectLater(sync.run(), throwsException);
      remote.loseAcknowledgment = false;
      await sync.run();
      await sync.run();
      expect((await r.progress()).xp, 10);
      expect(remote.events.length, 1);
    },
  );
  test(
    'two devices merge disjoint history and converge in any order',
    () async {
      final a = memoryRepository(), b = memoryRepository();
      addTearDown(a.db.close);
      addTearDown(b.db.close);
      await a.initialize();
      await b.initialize();
      await a.review(a.vocabulary.values.first, 'hello');
      await b.review(b.vocabulary.values.first, 'wrong');
      final remote = FakeRemote();
      final sa = SyncService(a, remote), sb = SyncService(b, remote);
      await sa.run();
      await sb.run();
      await sa.run();
      expect((await a.progress()).xp, 10);
      expect((await b.progress()).xp, 10);
      expect((await a.progress()).errors, 1);
      expect(await a.allEvents(), hasLength(2));
    },
  );
  test('another account cannot receive locally bound history', () async {
    final r = memoryRepository();
    addTearDown(r.db.close);
    await r.initialize();
    await r.setSetting('owner', 'user-b');
    await r.review(r.vocabulary.values.first, 'hello');
    final remote = FakeRemote();
    await expectLater(SyncService(r, remote).run(), throwsStateError);
    expect(remote.events, isEmpty);
    expect(await r.pending(), hasLength(1));
  });
  test('guest mode leaves queue untouched', () async {
    final r = memoryRepository();
    addTearDown(r.db.close);
    await r.initialize();
    await r.review(r.vocabulary.values.first, 'hello');
    final remote = FakeRemote()..userId = null;
    await SyncService(r, remote).run();
    expect(await r.pending(), hasLength(1));
    expect(remote.events, isEmpty);
  });
}
