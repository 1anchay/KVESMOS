import 'package:flutter/material.dart';
import '../domain/course.dart';

/// Optional help before answering. Opening it has no effect on XP or progress.
class LessonCoachCard extends StatelessWidget {
  final Lesson lesson;
  final Exercise exercise;

  const LessonCoachCard({
    super.key,
    required this.lesson,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    final words = lesson.vocabulary
        .where((word) => exercise.wordIds.contains(word.id))
        .toList();
    final advice = exercise.hint?.trim().isNotEmpty == true
        ? exercise.hint!
        : exercise.introduction?.trim().isNotEmpty == true
        ? exercise.introduction!
        : lesson.guide;
    final theme = Theme.of(context);

    return ExpansionTile(
      key: ValueKey('coach:${exercise.id}'),
      leading: const Icon(Icons.lightbulb_outline),
      title: const Text('Нужна подсказка?'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(advice, style: theme.textTheme.bodyLarge),
        if (words.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Слова в задании', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final word in words)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${word.en} — ${word.ru}'),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          'После проверки ответа появится объяснение, почему он подходит.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
