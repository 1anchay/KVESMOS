import 'dart:math';
import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../domain/progress.dart';
import 'design.dart';

class WeeklyActivity extends StatelessWidget {
  final AppController app;
  const WeeklyActivity(this.app, {super.key});
  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (i) => DateTime.now().subtract(Duration(days: 6 - i)),
    );
    final xp = days.map((d) => app.progress.dailyXp[dayKey(d)] ?? 0).toList();
    final maxXp = max(app.goal, xp.reduce(max));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${xp.reduce((a, b) => a + b)} XP за неделю',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 148,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  7,
                  (i) => Expanded(
                    child: Semantics(
                      label: '${dayKey(days[i])}: ${xp[i]} XP',
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 22,
                              height: 6 + 80 * xp[i] / maxXp,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: i == 6
                                      ? [cosmicBlue, turquoise]
                                      : [violet, const Color(0xFFC7B5F8)],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              child: Text(
                                [
                                  'Пн',
                                  'Вт',
                                  'Ср',
                                  'Чт',
                                  'Пт',
                                  'Сб',
                                  'Вс',
                                ][days[i].weekday - 1],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
