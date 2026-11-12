import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/placement_repository.dart';
import 'character_moment.dart';
import 'design.dart';
import 'lesson_effects.dart';
import 'lesson_preview.dart';

class PlacementPage extends ConsumerStatefulWidget {
  const PlacementPage({super.key});
  @override
  ConsumerState<PlacementPage> createState() => _PlacementPageState();
}

class _PlacementPageState extends ConsumerState<PlacementPage> {
  late final repository = PlacementRepository(ref.read(appProvider).repository);
  late Future<Map<String, dynamic>> load;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load = repository.open();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final exit = app.onboarded ? '/courses' : '/level';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Точка старта'),
        leading: IconButton(
          tooltip: 'Сохранить и выйти',
          icon: const Icon(Icons.close),
          onPressed: () => context.go(exit),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: load,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return pageBody([
              const Text(
                'Не удалось открыть диагностику. Сохрани уроки курса для офлайн-доступа.',
              ),
              TextButton(
                onPressed: () => context.go(exit),
                child: const Text('Вернуться'),
              ),
            ]);
          }
          final state = snapshot.data;
          if (state == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final questions = state['questions'] as List;
          final results = state['results'] as List;
          final done = results.length == questions.length;
          final info = app.repository.catalog
              .where((l) => l.id == state['recommendation'])
              .firstOrNull;
          final question = done ? null : questions[results.length] as Map;
          return pageBody([
            const CharacterMoment(
              characterId: 'orbi',
              size: 80,
              animate: false,
            ),
            Text(
              app.course.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              done ? 'Подходящая тема' : 'Проверим знакомые фразы',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text(
              'Диагностика помогает выбрать тему. XP и награды за неё не начисляются.',
            ),
            const SizedBox(height: 12),
            LessonProgress(done: results.length, total: questions.length),
            const SizedBox(height: 16),
            if (done) ...[
              Text(
                'Верных ответов: ${results.where((r) => r == true).length} из ${questions.length}',
              ),
              if (info != null)
                Text(info.title, style: Theme.of(context).textTheme.titleLarge),
              const Text(
                'Начало курса всегда доступно. Рекомендация сохранена в выборе языков.',
              ),
              if (app.onboarded && info != null)
                FilledButton(
                  onPressed: () => showLessonPreview(context, app, info),
                  child: const Text('Посмотреть рекомендованный урок'),
                ),
              TextButton(
                onPressed: () => context.go(app.onboarded ? '/map' : '/goal'),
                child: Text(
                  app.onboarded ? 'К карте курса' : 'Выбрать цель дня',
                ),
              ),
            ] else ...[
              Text('Вопрос ${results.length + 1} из ${questions.length}'),
              Text(
                question!['prompt'] as String,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final option in List<String>.from(question['options']))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => busy = true);
                            try {
                              final next = await repository.answer(
                                results.length,
                                option,
                              );
                              if (mounted) {
                                setState(() => load = Future.value(next));
                              }
                            } catch (_) {
                              if (context.mounted) {
                                showMessage(
                                  context,
                                  'Ответ не сохранён. Попробуй ещё раз.',
                                );
                              }
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: Text(option),
                  ),
                ),
              TextButton(
                onPressed: () =>
                    context.go(app.onboarded ? '/courses' : '/goal'),
                child: const Text('Пропустить диагностику'),
              ),
            ],
          ]);
        },
      ),
    );
  }
}
