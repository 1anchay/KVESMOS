import 'dart:convert';
import 'languages.dart';
import 'progress.dart';

class ReminderPreferences {
  final bool enabled, quiet;
  final int minute, quietStart, quietEnd;
  final Set<int> weekdays;
  final String courseId;
  final String? pausedUntil;
  const ReminderPreferences({
    this.enabled = false,
    this.quiet = true,
    this.minute = 1140,
    this.quietStart = 1320,
    this.quietEnd = 480,
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.courseId = 'ru-en',
    this.pausedUntil,
  });
  ReminderPreferences copyWith({
    bool? enabled,
    bool? quiet,
    int? minute,
    int? quietStart,
    int? quietEnd,
    Set<int>? weekdays,
    String? courseId,
    String? pausedUntil,
    bool resume = false,
  }) => ReminderPreferences(
    enabled: enabled ?? this.enabled,
    quiet: quiet ?? this.quiet,
    minute: minute ?? this.minute,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    weekdays: weekdays ?? this.weekdays,
    courseId: courseId ?? this.courseId,
    pausedUntil: resume ? null : pausedUntil ?? this.pausedUntil,
  );
  bool get timeIsQuiet =>
      quiet &&
      (quietStart == quietEnd ||
          (quietStart < quietEnd
              ? minute >= quietStart && minute < quietEnd
              : minute >= quietStart || minute < quietEnd));
  bool eligible(DateTime date, int xp, int goal) =>
      enabled &&
      weekdays.contains(date.weekday) &&
      !timeIsQuiet &&
      xp < goal &&
      (pausedUntil == null || dayKey(date).compareTo(pausedUntil!) >= 0);
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'quiet': quiet,
    'minute': minute,
    'quietStart': quietStart,
    'quietEnd': quietEnd,
    'weekdays': weekdays.toList()..sort(),
    'courseId': courseId,
    'pausedUntil': pausedUntil,
  };
  String encode() => jsonEncode(toJson());
  factory ReminderPreferences.decode(String? raw) {
    try {
      final j = jsonDecode(raw ?? '{}') as Map;
      int minute(String key, int fallback) =>
          (j[key] is int && j[key] >= 0 && j[key] < 1440) ? j[key] : fallback;
      return ReminderPreferences(
        enabled: j['enabled'] == true,
        quiet: j['quiet'] != false,
        minute: minute('minute', 1140),
        quietStart: minute('quietStart', 1320),
        quietEnd: minute('quietEnd', 480),
        weekdays: (j['weekdays'] as List? ?? [1, 2, 3, 4, 5, 6, 7])
            .whereType<int>()
            .where((d) => d >= 1 && d <= 7)
            .toSet(),
        courseId: StudyCourse.byId(j['courseId']).id,
        pausedUntil: DateTime.tryParse('${j['pausedUntil']}') == null
            ? null
            : j['pausedUntil'],
      );
    } catch (_) {
      return const ReminderPreferences();
    }
  }
}
