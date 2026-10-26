import 'progress.dart';

enum TodayMood { firstFlight, welcomeBack, returning, underway, complete }

/// Presentation only: the event ledger remains the source of XP and streaks.
class TodayJourney {
  final int xp, goal, streak;
  final TodayMood mood;
  TodayJourney(ProgressSnapshot progress, DateTime now, this.goal)
    : xp = progress.dailyXp[dayKey(now)] ?? 0,
      streak = progress.streak(now),
      mood = (progress.dailyXp[dayKey(now)] ?? 0) >= goal
          ? TodayMood.complete
          : (progress.dailyXp[dayKey(now)] ?? 0) > 0
          ? TodayMood.underway
          : progress.xp == 0
          ? TodayMood.firstFlight
          : progress.streak(now) == 0
          ? TodayMood.returning
          : TodayMood.welcomeBack;
  String get greeting => switch (mood) {
    TodayMood.firstFlight => 'Полетим вместе?',
    TodayMood.welcomeBack => 'Рад тебя видеть!',
    TodayMood.returning => 'Снова на орбите!',
    TodayMood.underway => 'Ты уже в пути!',
    TodayMood.complete => 'Сегодня получилось!',
  };
  String get message => switch (mood) {
    TodayMood.firstFlight =>
      'Я Орби. Один маленький урок — и первое открытие твоё.',
    TodayMood.welcomeBack => 'Продолжим с того места, где остановились.',
    TodayMood.returning => 'Все открытия на месте. Начнём в твоём темпе.',
    TodayMood.underway => 'Ещё ${goal - xp} XP до цели. Я рядом!',
    TodayMood.complete =>
      'Цель дня достигнута. Можно гордиться собой — и отдохнуть.',
  };
}
