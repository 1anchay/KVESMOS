import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/course.dart';
import 'character_moment.dart';
import 'design.dart';

Future<void> showLessonPreview(
  BuildContext context,
  AppController app,
  LessonInfo info,
) async {
  if (!app.installed.contains(info.id)) {
    context.go('/offline');
    return;
  }
  try {
    final preview = await app.repository.previewLesson(info.id);
    if (!context.mounted) return;
    final lesson = preview.lesson, session = preview.session;
    final type = Theme.of(context).textTheme;
    final start = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CharacterMoment(
                          characterId: 'orbi',
                          size: 52,
                          animate: false,
                          state: CharacterState.greeting,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            session == null
                                ? 'ТВОЙ СЛЕДУЮЩИЙ ШАГ'
                                : 'ПРОДОЛЖИМ С МЕСТА ОСТАНОВКИ',
                            style: type.labelSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lesson.title,
                      key: const Key('lesson-preview-title'),
                      style: type.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lesson.objective ?? lesson.guide,
                      style: type.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      session == null
                          ? 'Короткое объяснение · практика · открытие'
                          : 'Сохранено шагов: ${session.position} из ${lesson.exercises.length}',
                      style: type.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${lesson.exercises.length} заданий · точка отдыха посередине',
                      style: type.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text('Пригодится в разговоре', style: type.titleSmall),
                    const SizedBox(height: 8),
                    for (final word in lesson.vocabulary.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${word.en} — ${word.ru}'),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Слушай, собирай фразы и отвечай героям. Подсказка доступна в каждом задании.',
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('lesson-preview-start'),
                    onPressed: () => Navigator.of(sheet).pop(true),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      session == null ? 'Начать урок' : 'Продолжить урок',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (start == true && context.mounted) context.go('/lesson/${info.id}');
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Не удалось открыть обзор. Попробуйте ещё раз.');
    }
  }
}
