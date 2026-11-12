import 'progress.dart';

typedef ActivityDay = ({DateTime date, int xp, int lessons});

/// Events already store the local day on which they occurred. UTC here is
/// used only for calendar arithmetic, not to reinterpret those stored dates.
List<ActivityDay> activityDays(
  ProgressSnapshot progress,
  DateTime now,
  int count,
) => List.generate(count, (i) {
  final date = DateTime.utc(now.year, now.month, now.day - count + 1 + i);
  final key = dayKey(date);
  return (
    date: date,
    xp: progress.dailyXp[key] ?? 0,
    lessons: progress.dailyLessons[key] ?? 0,
  );
});

int bestActivityStreak(ProgressSnapshot progress, DateTime now) {
  final today = dayKey(now);
  final dates =
      progress.dailyXp.keys.where((day) => day.compareTo(today) <= 0).toList()
        ..sort();
  var best = 0, run = 0;
  DateTime? previous;
  for (final day in dates) {
    final date = DateTime.tryParse('${day}T00:00:00Z');
    if (date == null || (progress.dailyXp[day] ?? 0) <= 0) continue;
    run = previous != null && date.difference(previous).inDays == 1
        ? run + 1
        : 1;
    if (run > best) best = run;
    previous = date;
  }
  return best;
}
