import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/languages.dart';
import 'design.dart';

class CoursePicker extends ConsumerWidget {
  final bool onboarding;
  const CoursePicker({super.key, this.onboarding = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final course in StudyCourse.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: app.course.id == course.id
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                key: ValueKey('course-${course.id}'),
                contentPadding: const EdgeInsets.all(16),
                leading: Text(
                  course.flag,
                  style: const TextStyle(fontSize: 28),
                ),
                title: Text(course.name),
                subtitle: Text(
                  '${course.lessons} уроков · объяснения по-русски\nСвоя серия и повторения',
                ),
                trailing: app.course.id == course.id
                    ? const Icon(Icons.check_circle)
                    : null,
                onTap: () async {
                  await app.selectCourse(course.id);
                  if (context.mounted && !onboarding) context.go('/');
                },
              ),
            ),
          ),
        const Text(
          'Можно менять язык в любой момент. Пройденные уроки и начатые занятия сохраняются. Награды общие.',
        ),
      ],
    );
  }
}

class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});
  @override
  Widget build(BuildContext context) => pageBody([
    Text(
      'Три языка. Твой маршрут.',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 16),
    const CoursePicker(),
  ]);
}

class CourseSwitch extends ConsumerWidget {
  const CourseSwitch({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appProvider).course;
    return TextButton(
      key: const Key('switch-course'),
      onPressed: () => context.go('/courses'),
      child: Text(
        '${c.flag} ${c.language.toUpperCase()} ▾',
        semanticsLabel: 'Язык обучения: ${c.name}. Сменить язык',
      ),
    );
  }
}
