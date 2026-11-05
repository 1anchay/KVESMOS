import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/course.dart';
import '../domain/learning_unit.dart';
import 'character_moment.dart';
import 'design.dart';
import 'flight_components.dart';
import 'lesson_preview.dart';

class UnitGuidePage extends ConsumerWidget {
  const UnitGuidePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final units = LearningUnit.fromCatalog(app.repository.catalog);
    final current = units.where((u) => !u.mastered(app.progress)).firstOrNull;
    final type = Theme.of(context).textTheme;
    return pageBody([
      const CharacterMoment(characterId: 'orbi', size: 80, animate: false),
      Text('Маленькие шаги · большие открытия', style: type.headlineMedium),
      Text('${app.course.name} · цель, пример, применение и повторение'),
      const SizedBox(height: 16),
      if (current != null)
        FilledButton.icon(
          onPressed: () =>
              showLessonPreview(context, app, current.next(app.progress)!),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('Продолжить: ${current.next(app.progress)!.title}'),
        ),
      for (final unit in units) ...[
        const SizedBox(height: 20),
        FlightPanel(
          accent: unit.id == current?.id,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(unit.section, style: type.labelSmall),
              const SizedBox(height: 6),
              Text(unit.title, style: type.titleLarge),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: unit.completed(app.progress) / unit.lessons.length,
              ),
              Text(
                '${unit.completed(app.progress)} / ${unit.lessons.length} уроков завершено',
              ),
              for (final lesson in unit.lessons)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    app.progress.completed.contains(lesson.id)
                        ? Icons.check_circle_outline
                        : Icons.auto_stories_outlined,
                  ),
                  title: Text(lesson.title),
                  subtitle: Text(
                    app.repository.learningObjectives[lesson.id] ??
                        lesson.topic,
                  ),
                  onTap: () => showLessonPreview(context, app, lesson),
                ),
              OutlinedButton.icon(
                onPressed: () => _guide(context, app, unit),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Перед стартом · справочник'),
              ),
              if (unit.mastered(app.progress)) ...[
                const SizedBox(height: 8),
                const Text(
                  'Тема пройдена. Закрепим её по расписанию повторений.',
                ),
                TextButton.icon(
                  onPressed: () => context.go('/practice'),
                  icon: const Icon(Icons.psychology_outlined),
                  label: const Text('Повторить трудные слова'),
                ),
              ],
            ],
          ),
        ),
      ],
    ]);
  }

  Future<void> _guide(
    BuildContext context,
    AppController app,
    LearningUnit unit,
  ) async {
    try {
      // previewLesson reads pinned material without starting or advancing a run.
      final lessons = <Lesson>[];
      for (final info in unit.lessons) {
        if (app.installed.contains(info.id)) {
          lessons.add((await app.repository.previewLesson(info.id)).lesson);
        }
      }
      if (!context.mounted) return;
      if (lessons.isEmpty) {
        context.go('/offline');
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheet) => SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .8,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Перед стартом',
                style: Theme.of(sheet).textTheme.headlineMedium,
              ),
              for (final lesson in lessons) ...[
                const SizedBox(height: 20),
                Text(
                  lesson.objective ?? lesson.title,
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(lesson.guide),
                for (final word in lesson.vocabulary) ...[
                  const SizedBox(height: 10),
                  Text(word.en, style: Theme.of(sheet).textTheme.titleMedium),
                  if (word.pronunciation != null) Text(word.pronunciation!),
                  Text(word.ru),
                ],
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheet),
                child: const Text('Понятно'),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось открыть справочник. Проверьте загрузку уроков.',
            ),
          ),
        );
      }
    }
  }
}
