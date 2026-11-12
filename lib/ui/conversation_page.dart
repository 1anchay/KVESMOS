import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/conversation_repository.dart';
import 'character_moment.dart';
import 'design.dart';
import 'flight_components.dart';
import 'lesson_effects.dart';

class ConversationPage extends ConsumerStatefulWidget {
  final String? id;
  const ConversationPage({super.key, this.id});
  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  late final app = ref.read(appProvider);
  late Future<({List<Conversation> scenes, Map<String, dynamic>? state})> load;
  ConversationRepository? repository;
  final input = TextEditingController();
  bool busy = false, help = false, typing = false;
  @override
  void initState() {
    super.initState();
    load = open();
  }

  Future<({List<Conversation> scenes, Map<String, dynamic>? state})>
  open() async {
    final scenes = (await Conversation.load())
        .where((s) => s.language == app.course.language)
        .toList();
    if (widget.id == null) return (scenes: scenes, state: null);
    final scene = scenes.firstWhere((s) => s.id == widget.id);
    repository ??= ConversationRepository(app.repository, scene);
    final state = await repository!.open();
    if (mounted) input.text = state['text'];
    return (scenes: scenes, state: state);
  }

  Future<void> choose(
    List<Conversation> scenes,
    int step,
    String option,
  ) async {
    if (busy) return;
    setState(() => busy = true);
    FocusScope.of(context).unfocus();
    try {
      await app.audio.stop();
      final state = await repository!.advance(step, option);
      if (!mounted) return;
      setState(() {
        load = Future.value((scenes: scenes, state: state));
        input.text = state['text'];
      });
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Реплика не сохранилась. Попробуй ещё раз.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget bubble(
    String name,
    String character,
    DialogueLine line,
  ) => FlightPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CharacterMoment(characterId: character, size: 48, animate: false),
            const SizedBox(width: 8),
            Expanded(child: Text(name)),
          ],
        ),
        Text(line.text, style: Theme.of(context).textTheme.titleLarge),
        if (line.pronunciation != null) Text(line.pronunciation!),
        if (help) Text(line.meaning),
        TextButton.icon(
          onPressed: () async {
            final ok = await app.audio.speak(line.text, character: character);
            if (!ok && mounted) {
              showMessage(
                context,
                'Голос недоступен. Реплика остаётся на экране.',
              );
            }
          },
          icon: const Icon(Icons.volume_up_outlined),
          label: const Text('Послушать'),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    unawaited(app.audio.stop());
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Короткие разговоры'),
        leading: IconButton(
          tooltip: 'Сохранить и выйти',
          icon: const Icon(Icons.close),
          onPressed: busy
              ? null
              : () => context.go(
                  widget.id == null ? '/training' : '/conversations',
                ),
        ),
      ),
      body: FutureBuilder(
        future: load,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return pageBody([
              const Text('Разговор откроется после связанного урока.'),
              TextButton(
                onPressed: () => context.go('/conversations'),
                child: const Text('К разговорам'),
              ),
            ]);
          }
          final value = snapshot.data;
          if (value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final state = value.state, theme = Theme.of(context).textTheme;
          if (state == null) {
            return pageBody([
              Text(app.course.name, style: theme.titleMedium),
              Text('Выбери ситуацию', style: theme.headlineSmall),
              const Text('Твоя реплика меняет ответ собеседника.'),
              for (final scene in value.scenes) ...[
                const SizedBox(height: 12),
                FlightPanel(
                  child: ListTile(
                    title: Text(scene.title),
                    subtitle: Text(
                      app.progress.completed.contains(scene.prerequisite)
                          ? scene.goal
                          : 'После урока «${app.repository.catalog.firstWhere((l) => l.id == scene.prerequisite).title}»',
                    ),
                    trailing: Icon(
                      app.progress.completed.contains(scene.prerequisite)
                          ? Icons.chevron_right
                          : Icons.lock_outline,
                    ),
                    onTap: app.progress.completed.contains(scene.prerequisite)
                        ? () => context.go('/conversation/${scene.id}')
                        : null,
                  ),
                ),
              ],
            ]);
          }
          final scene = repository!.scene,
              step = state['step'] as int,
              branch = state['branch'] as int;
          final path = scene.paths[branch];
          final options = <DialogueLine>[
            for (final p in scene.paths)
              switch (step) {
                0 => p.request,
                1 => p.confirmation,
                _ => p.farewell,
              },
          ];
          return pageBody([
            Text(scene.title, style: theme.headlineSmall),
            Text(scene.goal),
            const SizedBox(height: 10),
            LessonProgress(done: step, total: 3),
            TextButton.icon(
              onPressed: () => setState(() => help = !help),
              icon: const Icon(Icons.translate),
              label: Text(help ? 'Скрыть перевод' : 'Показать перевод'),
            ),
            if (step == 0) bubble('Орби', 'orbi', scene.opening),
            if (step == 1) ...[
              Text('Твоя реплика: ${path.request.text}'),
              bubble('Мико', 'miko', path.reply),
            ],
            if (step == 2) ...[
              Text(path.confirmation.text),
              Text('Зиг ждёт последнюю реплику', style: theme.titleLarge),
              Text(path.farewell.meaning),
            ],
            if (step == 3) ...[
              bubble('Зиг', 'zig_quartz', path.closing),
              Text('Разговор завершён', style: theme.titleLarge),
              Text('Ты выбрал: ${path.request.meaning}'),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await repository!.restart();
                          if (mounted) {
                            setState(() {
                              load = open();
                              typing = false;
                            });
                          }
                        } catch (_) {
                          if (context.mounted) {
                            showMessage(
                              context,
                              'Не удалось начать разговор заново.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: const Text('Попробовать другой ответ'),
              ),
              FilledButton(
                onPressed: () => context.go('/conversations'),
                child: const Text('К разговорам'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              if (state['error'] == true)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    step == 1
                        ? 'Мико уточняет: ${path.reply.meaning} Выбери реплику про тот же вариант.'
                        : 'Зиг ждёт ответ именно на эту просьбу: ${path.farewell.meaning}',
                    style: theme.bodyLarge,
                  ),
                ),
              if (step == 2)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => typing = !typing),
                  child: Text(
                    typing ? 'Выбрать вариант' : 'Написать самостоятельно',
                  ),
                ),
              if (step == 2 && typing) ...[
                TextField(
                  controller: input,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    labelText: 'Ответ на изучаемом языке',
                  ),
                  onChanged: (text) async {
                    try {
                      await repository!.draft(text);
                    } catch (_) {
                      if (context.mounted) {
                        showMessage(context, 'Черновик не сохранён.');
                      }
                    }
                  },
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => choose(value.scenes, step, input.text),
                  child: const Text('Ответить'),
                ),
              ] else
                for (final option in options)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => choose(value.scenes, step, option.text),
                      child: Text(
                        [
                          option.text,
                          if (option.pronunciation != null)
                            option.pronunciation!,
                          if (help) option.meaning,
                        ].join('\n'),
                      ),
                    ),
                  ),
            ],
          ]);
        },
      ),
    );
  }
}
