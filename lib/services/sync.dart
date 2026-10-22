import '../data/repository.dart';
import '../domain/progress.dart';

abstract interface class SyncRemote {
  String? get userId;
  Future<void> push(List<LearningEvent> events);
  Future<List<LearningEvent>> pull();
}

class SyncService {
  final LearningRepository repository;
  final SyncRemote remote;
  bool busy = false;
  String status = 'Ожидает синхронизации';
  SyncService(this.repository, this.remote);
  Future<void> run() async {
    if (busy) {
      return;
    }
    final uid = remote.userId;
    if (uid == null) {
      status = 'Локальный режим · вход не выполнен';
      return;
    }
    busy = true;
    status = 'Синхронизация…';
    try {
      final owner = await repository.setting('owner');
      if (owner != null && owner != uid) {
        throw StateError(
          'Данные принадлежат другому аккаунту. Сначала выйдите и очистите локальные данные.',
        );
      }
      await repository.setSetting('owner', uid);
      final pending = await repository.pending();
      for (var offset = 0; offset < pending.length; offset += 200) {
        final batch = pending.skip(offset).take(200).toList();
        await remote.push(batch);
        if (remote.userId != uid) {
          throw StateError('Аккаунт изменился во время синхронизации.');
        }
        await repository.acknowledge(batch.map((e) => e.id).toList());
      }
      final incoming = await remote.pull();
      if (remote.userId != uid) {
        throw StateError('Аккаунт изменился во время синхронизации.');
      }
      await repository.db.transaction(() async {
        for (final e in incoming) {
          await repository.append(e, synced: true);
        }
      });
      await repository.setSetting('lastSync', DateTime.now().toIso8601String());
      status = 'Синхронизировано';
    } catch (_) {
      status = 'Не удалось синхронизировать · прогресс сохранён на устройстве';
      rethrow;
    } finally {
      busy = false;
    }
  }
}
