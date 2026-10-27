import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/domain/progress.dart';
import 'package:orbitwords/domain/explorer_profile.dart';

void main() {
  LearningEvent event(
    String id,
    String day,
    String kind,
    Map<String, dynamic> data,
  ) => LearningEvent(
    id: id,
    day: day,
    occurredAt: '${day}T12:00:00Z',
    kind: kind,
    data: data,
  );
  test(
    'records and first unlock dates use credited history, not repeated lessons or event IDs',
    () {
      final first = event('first', '2026-10-01', 'complete', {
        'session': 's1',
        'lesson': 'a1-01',
      });
      final events = [
        first,
        first,
        event('duplicate', '2026-10-02', 'complete', {
          'session': 's1',
          'lesson': 'a1-01',
        }),
        for (var i = 2; i <= 5; i++)
          event('s$i', '2026-10-${i.toString().padLeft(2, '0')}', 'complete', {
            'session': 's$i',
            'lesson': 'a1-0$i',
          }),
        event('miss', '2026-10-06', 'answer', {
          'session': 's6',
          'exercise': 'e1',
          'correct': false,
          'words': ['hello'],
        }),
        event('retry', '2026-10-09', 'complete', {
          'session': 's7',
          'lesson': 'a1-01',
        }),
      ];
      final p = ProgressSnapshot.fromEvents(events.reversed),
          records = ExplorerRecords.fromEvents(events.reversed, p);
      expect(p.xp, 120);
      expect(records.longestStreak, 5);
      expect(records.bestDailyXp, 20);
      expect(records.bestDay, '2026-10-01');
      expect(records.badgeDates, {
        'Первый контакт': '2026-10-01',
        'Исследователь': '2026-10-05',
      });
      for (final b in ExplorerBadge.all) {
        expect(b.earned(p), p.achievements.contains(b.name));
      }
    },
  );
  test('empty profile has no invented date, record or earned badge', () {
    final p = ProgressSnapshot(),
        r = ExplorerRecords.fromEvents([], ProgressSnapshot());
    expect(r.bestDay, isNull);
    expect(r.longestStreak, 0);
    expect(r.bestDailyXp, 0);
    expect(r.badgeDates, isEmpty);
    expect(ExplorerBadge.all.where((b) => b.earned(p)), isEmpty);
  });
  test('one exercise earns XP once, even when retried on a later day', () {
    final events = [
      for (var i = 0; i < 101; i++)
        event('$i', '2026-10-${i == 100 ? '02' : '01'}', 'answer', {
          'session': 's',
          'exercise': i == 100 ? '0' : '$i',
          'correct': true,
          'words': ['word$i'],
        }),
    ];
    final p = ProgressSnapshot.fromEvents(events),
        r = ExplorerRecords.fromEvents(events, p);
    expect(p.xp, 1000);
    expect(r.bestDailyXp, 1000);
    expect(r.longestStreak, 1);
    expect(r.badgeDates['Тысяча звёзд'], '2026-10-01');
    expect(r.badgeDates['Хранитель слов'], '2026-10-01');
  });
}
