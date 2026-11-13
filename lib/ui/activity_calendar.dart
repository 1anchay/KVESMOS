import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../domain/activity_calendar.dart';
import '../domain/progress.dart';

class ActivityCalendar extends StatefulWidget {
  final AppController app;
  const ActivityCalendar(this.app, {super.key});
  @override
  State<ActivityCalendar> createState() => _ActivityCalendarState();
}

class _ActivityCalendarState extends State<ActivityCalendar> {
  String? selectedDay;
  @override
  Widget build(BuildContext context) {
    final app = widget.app, now = app.repository.now();
    final days = activityDays(app.progress, now, 30);
    final selected =
        days.where((d) => dayKey(d.date) == selectedDay).firstOrNull ??
        days.last;
    final week = days.skip(23);
    final xp = week.fold(0, (total, d) => total + d.xp);
    final lessons = week.fold(0, (total, d) => total + d.lessons);
    final theme = Theme.of(context), colors = theme.colorScheme;
    final local = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('30 дней занятий', style: theme.textTheme.titleLarge),
            Text(app.course.name),
            const SizedBox(height: 8),
            Text(
              'Серия: ${app.progress.streak(now)} дн. · Рекорд: ${bestActivityStreak(app.progress, now)} дн.',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 7 * 48 ? 7 : 5;
                final width =
                    (constraints.maxWidth - (columns - 1) * 2) / columns;
                return Wrap(
                  spacing: 2,
                  runSpacing: 4,
                  children: [
                    for (final day in days)
                      SizedBox(
                        width: width,
                        height: 52,
                        child: Semantics(
                          button: true,
                          selected: day.date == selected.date,
                          onTap: () =>
                              setState(() => selectedDay = dayKey(day.date)),
                          label:
                              '${local.formatFullDate(day.date)}, ${day.xp} XP, уроков ${day.lessons}${day.xp >= app.goal ? ', цель достигнута' : ''}',
                          child: ExcludeSemantics(
                            child: Material(
                              color: day.xp >= app.goal
                                  ? colors.primaryContainer
                                  : day.xp > 0
                                  ? colors.secondaryContainer
                                  : colors.surfaceContainerLow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: day.date == selected.date
                                    ? BorderSide(
                                        color: colors.primary,
                                        width: 2,
                                      )
                                    : BorderSide.none,
                              ),
                              child: InkWell(
                                key: ValueKey('activity:${dayKey(day.date)}'),
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => setState(
                                  () => selectedDay = dayKey(day.date),
                                ),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('${day.date.day}'),
                                        if (day.xp > 0)
                                          Icon(
                                            day.xp >= app.goal
                                                ? Icons.check_rounded
                                                : Icons.circle,
                                            size: 12,
                                            color: colors.onSurface,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                '${local.formatFullDate(selected.date)} · ${selected.xp} XP · уроков: ${selected.lessons}',
              ),
            ),
            Text('Галочка: набрана текущая цель ${app.goal} XP.'),
            const Divider(),
            Text('Последние 7 дней', style: theme.textTheme.titleMedium),
            Text(
              xp == 0
                  ? 'Здесь появятся результаты, когда начнёшь заниматься.'
                  : 'Уроков: $lessons · $xp XP · дней с занятиями: ${week.where((d) => d.xp > 0).length}.',
            ),
          ],
        ),
      ),
    );
  }
}
