import 'progress.dart';

class ExplorerBadge {
  final String name, requirement, kind;
  final int target, tier;
  const ExplorerBadge(
    this.name,
    this.requirement,
    this.kind,
    this.target,
    this.tier,
  );
  static const all = [
    ExplorerBadge('Первый контакт', 'Заверши первую миссию', 'missions', 1, 1),
    ExplorerBadge('Исследователь', 'Заверши 5 разных миссий', 'missions', 5, 2),
    ExplorerBadge(
      'Новая планета',
      'Заверши 10 разных миссий',
      'missions',
      10,
      3,
    ),
    ExplorerBadge(
      'Созвездие A1',
      'Заверши 20 миссий вводного маршрута',
      'missions',
      20,
      4,
    ),
    ExplorerBadge(
      'Хранитель слов',
      'Встреть в заданиях 30 разных слов',
      'words',
      30,
      2,
    ),
    ExplorerBadge('Тысяча звёзд', 'Заработай 1000 XP', 'xp', 1000, 3),
  ];
  int value(ProgressSnapshot p) => switch (kind) {
    'words' => p.words.length,
    'xp' => p.xp,
    _ => p.completed.length,
  };
  bool earned(ProgressSnapshot p) => value(p) >= target;
}

/// Read-only records over the original ledger, not a new source of XP/rewards.
class ExplorerRecords {
  final int longestStreak, bestDailyXp;
  final String? bestDay;
  final Map<String, String> badgeDates;
  const ExplorerRecords({
    this.longestStreak = 0,
    this.bestDailyXp = 0,
    this.bestDay,
    this.badgeDates = const {},
  });

  factory ExplorerRecords.fromEvents(
    Iterable<LearningEvent> source,
    ProgressSnapshot progress,
  ) {
    final days = progress.dailyXp.keys.toList()..sort();
    var longest = 0, run = 0, best = 0;
    String? bestDay;
    DateTime? previous;
    for (final day in days) {
      final date = DateTime.parse('${day}T00:00:00Z');
      run = previous != null && date.difference(previous).inDays == 1
          ? run + 1
          : 1;
      if (run > longest) longest = run;
      if (progress.dailyXp[day]! > best) {
        best = progress.dailyXp[day]!;
        bestDay = day;
      }
      previous = date;
    }
    final events = {for (final e in source) e.id: e}.values.toList()
      ..sort((a, b) {
        final c = DateTime.parse(
          a.occurredAt,
        ).compareTo(DateTime.parse(b.occurredAt));
        return c == 0 ? a.id.compareTo(b.id) : c;
      });
    final missions = <String>{},
        words = <String>{},
        credits = <String>{},
        completedRuns = <String>{};
    final dates = <String, String>{};
    var xp = 0;
    for (final e in events) {
      if (e.kind == 'answer') {
        words.addAll(List<String>.from(e.data['words'] ?? []));
        if (e.data['correct'] == true &&
            credits.add('${e.data['session']}:${e.data['exercise']}')) {
          xp += 10;
        }
      } else if (e.kind == 'complete' &&
          completedRuns.add('${e.data['session']}')) {
        missions.add(e.data['lesson'] as String);
        xp += 20;
      }
      for (final badge in ExplorerBadge.all) {
        final value = badge.kind == 'xp'
            ? xp
            : badge.kind == 'words'
            ? words.length
            : missions.length;
        if (value >= badge.target) dates.putIfAbsent(badge.name, () => e.day);
      }
    }
    return ExplorerRecords(
      longestStreak: longest,
      bestDailyXp: best,
      bestDay: bestDay,
      badgeDates: dates,
    );
  }
}
