import 'progress.dart';
import 'rewards.dart';

class DailyMission {
  final String id, title, description, chest;
  final int target;
  const DailyMission(
    this.id,
    this.title,
    this.description,
    this.target,
    this.chest,
  );
  String grantId(String day) => 'daily:v1:$day:$id';
  static const all = [
    DailyMission(
      'lesson',
      'Завершить один урок',
      'Подойдёт новый урок или повторное прохождение.',
      1,
      'explorer',
    ),
    DailyMission(
      'answers',
      'Дать 10 верных ответов',
      'В уроках, приключениях и повторении слов. Ошибки не отнимают прогресс.',
      10,
      'explorer',
    ),
    DailyMission(
      'review',
      'Повторить пять знакомых слов',
      'Пять разных слов в разделе «Повторение». Засчитываются и попытки с ошибкой.',
      5,
      'nebula',
    ),
  ];
}

class MissionDay {
  int lessons = 0, answers = 0;
  final Set<String> reviewed = {};
  int count(DailyMission mission) => switch (mission.id) {
    'lesson' => lessons,
    'answers' => answers,
    'review' => reviewed.length,
    _ => 0,
  };
  bool completed(DailyMission mission) => count(mission) >= mission.target;
}

class MissionSnapshot {
  final String day;
  final MissionDay progress;
  final Inventory inventory;
  MissionSnapshot(this.day, this.progress, this.inventory);
  bool awarded(DailyMission mission) =>
      inventory.grants.containsKey(mission.grantId(day));
}

/// event.day is the calendar date recorded when studying; timezone changes never
/// move previous work between dates. Review counts distinct, previously seen
/// words, with an earlier timestamp; repeated attempts cannot fill all 5 slots.
Map<String, MissionDay> missionHistory(
  Iterable<LearningEvent> input, {
  required String since,
  required String through,
}) {
  final events = {for (final event in input) event.id: event}.values.toList()
    ..sort((a, b) {
      final order = DateTime.parse(
        a.occurredAt,
      ).compareTo(DateTime.parse(b.occurredAt));
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
  final days = <String, MissionDay>{};
  final correctQuestions = <String>{}, completedSessions = <String>{};
  final seenWords = <String, DateTime>{};
  for (final event in events) {
    final d = event.data;
    final inRange =
        event.day.compareTo(since) >= 0 && event.day.compareTo(through) <= 0;
    final day = inRange ? days.putIfAbsent(event.day, MissionDay.new) : null;
    if (event.kind == 'answer') {
      final at = DateTime.parse(event.occurredAt);
      final exercise = d['exercise'] as String;
      if (d['correct'] == true &&
          correctQuestions.add('${d['session']}:$exercise')) {
        if (day != null) day.answers++;
      }
      final words = List<String>.from(d['words'] ?? []);
      if (exercise.startsWith('review:') && day != null) {
        final word = exercise.substring('review:'.length);
        if (words.contains(word) && seenWords[word]?.isBefore(at) == true) {
          day.reviewed.add(word);
        }
      }
      for (final word in words) {
        seenWords.putIfAbsent(word, () => at);
      }
    } else if (event.kind == 'complete' &&
        completedSessions.add(d['session'] as String)) {
      if (day != null) day.lessons++;
    }
  }
  return days;
}
