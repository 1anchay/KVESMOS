import 'dart:math';

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class LearningEvent {
  final String id, kind, occurredAt, day;
  final Map<String, dynamic> data;
  const LearningEvent({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.day,
    required this.data,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'occurred_at': occurredAt,
    'day': day,
    'data': data,
  };
  factory LearningEvent.fromJson(Map<String, dynamic> j) => LearningEvent(
    id: j['id'],
    kind: j['kind'],
    occurredAt: j['occurred_at'],
    day: j['day'],
    data: Map<String, dynamic>.from(j['data']),
  );
}

/// SM-2 with binary grades: correct=4, error=1. One scheduling update per word
/// per UTC day; mistakes downgrade that day's grade. Retries cannot inflate intervals.
class WordProgress {
  int correct = 0, errors = 0, repetitions = 0, interval = 0;
  double ease = 2.5;
  DateTime? last, next;
  double get mastery => min(1.0, repetitions / 6);
  void schedule(bool passed, DateTime time) {
    final q = passed ? 4 : 1;
    if (passed) {
      interval = repetitions == 0
          ? 1
          : repetitions == 1
          ? 6
          : (interval * ease).round();
      repetitions++;
    } else {
      repetitions = 0;
      interval = 1;
    }
    ease = max(1.3, ease + 0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    last = time;
    next = time.add(Duration(days: interval));
  }
}

class ProgressSnapshot {
  int xp = 0, correct = 0, errors = 0;
  final Set<String> completed = {};
  final Map<String, int> dailyXp = {}, dailyLessons = {};
  final Map<String, WordProgress> words = {};
  int get level => 1 + xp ~/ 250;
  int streak(DateTime today) {
    var cursor = DateTime(today.year, today.month, today.day);
    if (!dailyXp.containsKey(dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var result = 0;
    while (dailyXp.containsKey(dayKey(cursor))) {
      result++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return result;
  }

  List<String> get achievements => [
    if (completed.isNotEmpty) 'Первый контакт',
    if (completed.length >= 5) 'Исследователь',
    if (completed.length >= 10) 'Новая планета',
    if (completed.length >= 20) 'Созвездие A1',
    if (words.length >= 30) 'Хранитель слов',
    if (xp >= 1000) 'Тысяча звёзд',
  ];
  static ProgressSnapshot fromEvents(Iterable<LearningEvent> input) {
    final result = ProgressSnapshot();
    final unique = {for (final e in input) e.id: e}.values.toList()
      ..sort((a, b) {
        final c = DateTime.parse(
          a.occurredAt,
        ).compareTo(DateTime.parse(b.occurredAt));
        return c == 0 ? a.id.compareTo(b.id) : c;
      });
    final credited = <String>{};
    final completedRuns = <String>{};
    final wordDays = <String, Map<String, (bool, DateTime)>>{};
    for (final event in unique) {
      final d = event.data;
      var gained = 0;
      if (event.kind == 'answer') {
        final passed = d['correct'] == true;
        if (passed) {
          result.correct++;
        } else {
          result.errors++;
        }
        if (passed && credited.add('${d['session']}:${d['exercise']}')) {
          gained = 10;
        }
        final at = DateTime.parse(event.occurredAt).toUtc();
        for (final word in List<String>.from(d['words'] ?? [])) {
          final state = result.words.putIfAbsent(word, WordProgress.new);
          if (passed) {
            state.correct++;
          } else {
            state.errors++;
          }
          final days = wordDays.putIfAbsent(word, () => {});
          final key = dayKey(at);
          final previous = days[key];
          days[key] = ((previous?.$1 ?? true) && passed, at);
        }
      } else if (event.kind == 'complete' &&
          completedRuns.add(d['session'] as String)) {
        gained = 20;
        result.completed.add(d['lesson']);
        result.dailyLessons.update(event.day, (v) => v + 1, ifAbsent: () => 1);
      }
      if (gained > 0) {
        result.xp += gained;
        result.dailyXp.update(
          event.day,
          (v) => v + gained,
          ifAbsent: () => gained,
        );
      }
    }
    for (final entry in wordDays.entries) {
      final sorted = entry.value.keys.toList()..sort();
      for (final key in sorted) {
        final grade = entry.value[key]!;
        result.words[entry.key]!.schedule(grade.$1, grade.$2);
      }
    }
    return result;
  }
}
