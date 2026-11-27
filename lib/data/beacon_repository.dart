import 'dart:convert';
import 'repository.dart';

class BeaconState {
  static const prefix = 'kvesmos.beacon.v1:';
  final int stage;
  final String target;
  final String? session;
  const BeaconState(this.stage, this.target, [this.session]);

  String encode() =>
      jsonEncode({'stage': stage, 'target': target, 'session': session});
  factory BeaconState.decode(String value) {
    final map = jsonDecode(value) as Map<String, dynamic>;
    final state = BeaconState(
      map['stage'] as int,
      map['target'] as String,
      map['session'] as String?,
    );
    if (state.stage < 0 ||
        state.stage > 5 ||
        state.target.isEmpty ||
        (state.stage < 3 && state.session != null)) {
      throw const FormatException('Некорректная запись экспедиции');
    }
    return state;
  }
}

class BeaconRepository {
  final LearningRepository learning;
  BeaconRepository(this.learning);
  String get key => '${BeaconState.prefix}${learning.course.id}';

  Future<BeaconState> read(String fallback) =>
      learning.db.transaction(() async {
        final raw = await learning.setting(key);
        BeaconState value;
        if (raw == null) {
          final legacy = (await learning.setting(
            'beacon_chapter_v1_${learning.course.language}',
          ))?.split('|');
          value =
              legacy != null &&
                  legacy.length == 2 &&
                  learning.catalog.any((l) => l.id == legacy.last)
              ? BeaconState(
                  (int.tryParse(legacy.first) ?? 0).clamp(0, 5),
                  legacy.last,
                )
              : BeaconState(0, fallback);
          if (legacy != null) await learning.setSetting(key, value.encode());
        } else {
          value = BeaconState.decode(raw);
        }
        if (value.stage == 3 && value.session != null) {
          final completed = (await learning.allEvents()).any(
            (e) =>
                e.kind == 'complete' &&
                e.data['session'] == value.session &&
                e.data['lesson'] == value.target,
          );
          if (completed) {
            value = BeaconState(4, value.target, value.session);
            await learning.setSetting(key, value.encode());
          }
        }
        return value;
      });

  Future<BeaconState> advance(BeaconState expected) => learning.db.transaction(
    () async {
      final current = await read(expected.target);
      if (current.stage != expected.stage || current.stage >= 5) return current;
      final next = BeaconState(
        current.stage == 3 ? 3 : current.stage + 1,
        current.target,
        current.session,
      );
      await learning.setSetting(key, next.encode());
      return next;
    },
  );

  Future<void> bind(String target, String sessionId) =>
      learning.db.transaction(() async {
        final current = await read(target);
        final session = await learning.session(sessionId);
        if (current.stage == 3 &&
            current.target == target &&
            session.lessonId == target &&
            !session.done) {
          await learning.setSetting(
            key,
            BeaconState(3, target, sessionId).encode(),
          );
        }
      });
}
