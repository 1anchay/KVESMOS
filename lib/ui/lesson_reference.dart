import 'package:flutter/material.dart';
import '../domain/course.dart';

Future<void> showLessonReference(
  BuildContext context,
  Lesson lesson, {
  VoidCallback? onTry,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Справочник', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(lesson.guide),
          if (onTry != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onTry();
              },
              icon: const Icon(Icons.touch_app_outlined),
              label: const Text('Попробовать с Орби'),
            ),
          for (final step in lesson.teachingSteps) ...[
            const Divider(height: 32),
            Text(step.phrase, style: Theme.of(context).textTheme.titleLarge),
            if (step.pronunciation != null) Text(step.pronunciation!),
            Text(step.translation),
            const SizedBox(height: 8),
            Text(step.explanation),
          ],
        ],
      ),
    ),
  ),
);
