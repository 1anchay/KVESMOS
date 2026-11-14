import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/smart_placement_repository.dart';
import '../domain/course.dart';
import '../domain/learning_unit.dart';
import 'character_moment.dart';
import 'design.dart';
import 'lesson_effects.dart';

class PlacementPage extends ConsumerStatefulWidget {
  const PlacementPage({super.key});
  @override
  ConsumerState<PlacementPage> createState() => _PlacementPageState();
}

class _PlacementPageState extends ConsumerState<PlacementPage> {
  late final app = ref.read(appProvider);
  late final repository = SmartPlacementRepository(app.repository);
  late final saved = repository.saved();
  Future<Map<String, dynamic>>? load;
  final input = TextEditingController();
  final selected = <int>[];
  bool busy = false, examples = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> start(LessonInfo lesson) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await app.repository.chooseCourseStart(lesson.id);
      await app.refresh();
      if (mounted) {
        context.go(
          !app.onboarded
              ? '/goal'
              : app.installed.contains(lesson.id)
              ? '/lesson/${lesson.id}'
              : '/offline',
        );
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Не удалось сохранить точку старта.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> answer(String id, String value) async {
    if (busy || value.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      final state = await repository.answer(id, value);
      if (mounted) {
        setState(() {
          input.clear();
          selected.clear();
          load = Future.value(state);
        });
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Ответ не сохранён. Попробуй ещё раз.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final catalog = app.repository.catalog;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Точка старта'),
        leading: IconButton(
          tooltip: 'Сохранить и выйти',
          icon: const Icon(Icons.close),
          onPressed: () => context.go(app.onboarded ? '/courses' : '/language'),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: load,
        builder: (context, snapshot) {
          final state = snapshot.data;
          final item = state == null
              ? null
              : SmartPlacementRepository.question(state);
          final info = catalog
              .where((l) => l.id == state?['recommendation'])
              .firstOrNull;
          final unit = LearningUnit.fromCatalog(
            catalog,
          ).where((u) => u.lessons.contains(info)).firstOrNull;
          final tokens = List<String>.from(item?['tokens'] ?? []);
          final results = List<Map<String, dynamic>>.from(
            state?['results'] ?? [],
          );
          final level = state?['level'] as int? ?? 0;
          return pageBody([
            const CharacterMoment(
              characterId: 'orbi',
              size: 80,
              animate: false,
            ),
            Text(app.course.name, style: type.titleMedium),
            if (load == null || snapshot.hasError) ...[
              Text('С чего начнём?', style: type.headlineSmall),
              const Text(
                'Орби поможет выбрать тему. Начало курса всегда доступно.',
              ),
              if (app.courseStart.entry case final entry?)
                Text('Выбранный старт: ${entry.title}'),
              FutureBuilder<Map<String, dynamic>?>(
                future: saved,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final level = data?['level'] ?? data?['previous']?['level'];
                  if (level is! int || level < 0 || level > 2) {
                    return const SizedBox.shrink();
                  }
                  return Text('Последний результат: ${_levels[level]}');
                },
              ),
              if (snapshot.hasError)
                const Text(
                  'Не удалось открыть тест. Можно повторить или начать курс.',
                ),
              FilledButton(
                onPressed: busy ? null : () => start(catalog.first),
                child: const Text('Начать с нуля'),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  load = repository.open();
                }),
                child: const Text('Проверить мои знания'),
              ),
            ] else if (state == null)
              const LinearProgressIndicator()
            else if (info != null) ...[
              Text(_levels[level], style: type.headlineSmall),
              Text(
                'Верных ответов: ${results.where((r) => r['correct'] == true).length} из ${results.length}',
              ),
              const Text(
                'Это подсказка для выбора темы. XP и награды за тест не начисляются.',
              ),
              Text(unit?.title ?? info.title, style: type.titleLarge),
              Text('Первый урок: ${info.title}'),
              Text(
                level == 0
                    ? 'Начни с первых фраз и закрепи их в диалоге.'
                    : 'Вспомни знакомые конструкции, затем попробуй новые примеры в уроке.',
              ),
              for (final skill in results.map((r) => r['skill']).toSet())
                Text(
                  '$skill · ${results.where((r) => r['skill'] == skill && r['correct'] == true).length} из ${results.where((r) => r['skill'] == skill).length}',
                ),
              TextButton(
                onPressed: () => setState(() => examples = !examples),
                child: const Text('Посмотреть примеры'),
              ),
              if (examples)
                FutureBuilder(
                  future: app.repository.loadAsset(info.asset),
                  builder: (context, snapshot) => snapshot.hasData
                      ? Text(
                          Lesson.fromJson(jsonDecode(snapshot.data!))
                              .teachingSteps
                              .take(2)
                              .map((s) => '${s.phrase} — ${s.translation}')
                              .join('\n'),
                        )
                      : const LinearProgressIndicator(),
                ),
              FilledButton(
                onPressed: busy ? null : () => start(info),
                child: const Text('Начать с рекомендованного'),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => start(catalog.first),
                child: const Text('Начать с начала'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        load = repository.open(restart: true);
                      }),
                child: const Text('Пройти тест заново'),
              ),
            ] else if (item != null) ...[
              LessonProgress(done: results.length, total: 12),
              Text('Задание ${results.length + 1}', style: type.titleMedium),
              if (item['scene'] != null) Text(item['scene']),
              if (item['pinyin'] != null) Text(item['pinyin']),
              Text(item['prompt'], style: type.titleLarge),
              if (tokens.isNotEmpty) ...[
                Text(selected.map((i) => tokens[i]).join(' ')),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (index, token)
                        in tokens.indexed.toList().reversed)
                      OutlinedButton(
                        key: ValueKey('placement-token-$index'),
                        onPressed: busy || selected.contains(index)
                            ? null
                            : () => setState(() => selected.add(index)),
                        child: Text(token),
                      ),
                  ],
                ),
                TextButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => setState(() => selected.removeLast()),
                  child: const Text('Убрать последнее слово'),
                ),
                FilledButton(
                  onPressed: busy || selected.isEmpty
                      ? null
                      : () => answer(
                          item['id'],
                          selected.map((i) => tokens[i]).join(' '),
                        ),
                  child: const Text('Ответить'),
                ),
              ] else if ((item['options'] as List).isNotEmpty)
                for (final option in List<String>.from(item['options']))
                  OutlinedButton(
                    onPressed: busy ? null : () => answer(item['id'], option),
                    child: Text(option),
                  )
              else ...[
                TextField(
                  controller: input,
                  maxLength: 400,
                  decoration: const InputDecoration(labelText: 'Твой ответ'),
                ),
                FilledButton(
                  onPressed: busy ? null : () => answer(item['id'], input.text),
                  child: const Text('Ответить'),
                ),
              ],
              TextButton(
                onPressed: busy ? null : () => answer(item['id'], '∅'),
                child: const Text('Не знаю'),
              ),
              TextButton(
                onPressed: busy ? null : () => start(catalog.first),
                child: const Text('Пропустить диагностику'),
              ),
            ],
          ]);
        },
      ),
    );
  }
}

const _levels = [
  'Начинающий',
  'Знаю основы',
  'Уверенно использую знакомые темы',
];
