import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/mastery_repository.dart';
import '../domain/learning_unit.dart';
import '../services/learning_audio.dart';
import 'character_moment.dart';
import 'lesson_effects.dart';
import 'mastery_stamp.dart';

class UnitMasteryPage extends ConsumerStatefulWidget {
  final String unitId;
  const UnitMasteryPage({super.key, required this.unitId});
  @override
  ConsumerState<UnitMasteryPage> createState() => _UnitMasteryPageState();
}

class _UnitMasteryPageState extends ConsumerState<UnitMasteryPage> {
  MasteryRepository? mastery;
  Map<String, dynamic>? state;
  final input = TextEditingController();
  bool busy = false, stamped = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool restart = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final app = ref.read(appProvider);
      final unit = LearningUnit.fromCatalog(
        app.repository.catalog,
      ).where((u) => u.id == widget.unitId).firstOrNull;
      if (unit == null) throw StateError('Тема не найдена.');
      mastery ??= MasteryRepository(app.repository, unit);
      final value = await mastery!.open(restart: restart);
      final earned = await mastery!.earned();
      await ref.read(appProvider).refresh();
      if (!mounted) return;
      setState(() {
        state = value;
        stamped = earned;
        input.text = value['text'];
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message
              : 'Не удалось открыть проверку.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> next() async {
    if (busy || state == null) return;
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      final old = state!;
      final value = await mastery!.advance(
        old['index'],
        old['checked'],
        input.text,
      );
      final earned = await mastery!.earned();
      await ref.read(appProvider).refresh();
      if (!mounted) return;
      setState(() {
        state = value;
        stamped = earned;
        input.text = value['text'];
      });
      unawaited(
        ref
            .read(appProvider)
            .audio
            .play(
              value['done'] == true && value['passed'] == true
                  ? SoundEffect.achievement
                  : old['checked'] == true
                  ? SoundEffect.tap
                  : value['correct'] == true
                  ? SoundEffect.correct
                  : SoundEffect.incorrect,
            ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ответ не сохранён. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final value = state;
    final type = Theme.of(context).textTheme;
    final finished = value?['done'] == true;
    final checked = value?['checked'] == true;
    final items = value?['items'] as List? ?? [];
    final item = value == null || finished
        ? null
        : items[value['index']] as Map;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Созвездие знаний'),
        leading: IconButton(
          tooltip: 'Закрыть и сохранить',
          icon: const Icon(Icons.close),
          onPressed: busy ? null : () => context.go('/map'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(error!),
                      TextButton(
                        onPressed: load,
                        child: const Text('Повторить'),
                      ),
                    ],
                  )
                : value == null
                ? const Center(child: CircularProgressIndicator())
                : app.course.id != mastery!.courseId
                ? const Text('Переключаем курс…')
                : Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            CharacterMoment(
                              characterId: finished && value['passed'] == true
                                  ? 'orbi'
                                  : 'miko',
                              size: 72,
                              animate: app.audio.preferences.reactions,
                              state: finished && value['passed'] == true
                                  ? CharacterState.celebration
                                  : checked
                                  ? value['correct'] == true
                                        ? CharacterState.correct
                                        : CharacterState.support
                                  : CharacterState.thinking,
                            ),
                            const SizedBox(height: 12),
                            Text(mastery!.unit.title, style: type.titleLarge),
                            const SizedBox(height: 16),
                            LessonProgress(
                              done: value['index'],
                              total: items.length,
                            ),
                            const SizedBox(height: 20),
                            if (finished) ...[
                              if (stamped) const Center(child: MasteryStamp()),
                              Text(
                                value['passed'] == true
                                    ? 'Созвездие собрано!'
                                    : 'Ещё немного практики',
                                style: type.headlineSmall,
                              ),
                              Text(
                                'Без подсказок: ${value['score']} из ${items.length} реплик.',
                              ),
                              const Text(
                                'Это проверка знакомого материала, а не оценка уровня языка. Повторная проверка не выдаёт XP и сундуки.',
                              ),
                              if ((value['difficult'] as List).isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text('Что повторить', style: type.titleMedium),
                                for (final word in items.where(
                                  (w) => (value['difficult'] as List).contains(
                                    w['id'],
                                  ),
                                ))
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(word['phrase']),
                                    subtitle: Text(
                                      '${word['pronunciation'] == null ? '' : '${word['pronunciation']}\n'}${word['meaning']}',
                                    ),
                                  ),
                                OutlinedButton(
                                  onPressed: () => context.go(
                                    '/practice/words?unit=${mastery!.unit.lessons.map((l) => l.id).join(',')}',
                                  ),
                                  child: const Text('Короткое повторение темы'),
                                ),
                              ],
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => load(restart: true),
                                child: const Text('Проверить ещё раз'),
                              ),
                            ] else ...[
                              const Text(
                                'Вспомни реплику без вариантов. Подсказка появится после ответа.',
                              ),
                              const SizedBox(height: 16),
                              Text(item!['meaning'], style: type.headlineSmall),
                              const SizedBox(height: 20),
                              TextField(
                                key: const Key('mastery-input'),
                                controller: input,
                                enabled: !busy && !checked,
                                minLines: 1,
                                maxLines: 3,
                                textInputAction: TextInputAction.done,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  hintText: app.course.language == 'zh'
                                      ? 'Иероглифы или пиньинь с тонами'
                                      : 'Ответ на изучаемом языке',
                                ),
                                onChanged: (text) async {
                                  setState(() {});
                                  try {
                                    await mastery!.draft(value['index'], text);
                                  } catch (_) {
                                    if (mounted) {
                                      setState(
                                        () => error =
                                            'Не удалось сохранить черновик.',
                                      );
                                    }
                                  }
                                },
                              ),
                              if (checked)
                                Semantics(
                                  liveRegion: true,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          value['correct'] == true
                                              ? 'Ты вспомнил!'
                                              : 'Сверим с примером',
                                          style: type.titleLarge,
                                        ),
                                        Text(item['phrase']),
                                        if (item['pronunciation'] != null)
                                          Text(item['pronunciation']),
                                        Text(item['meaning']),
                                        if (item['explanation'] != null)
                                          Text(item['explanation']),
                                        if (value['correct'] == false)
                                          const Text(
                                            'Вернём эту реплику в короткое повторение после проверки.',
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const Key('mastery-next'),
                            onPressed:
                                busy ||
                                    (!finished &&
                                        !checked &&
                                        input.text.trim().isEmpty)
                                ? null
                                : finished
                                ? () => context.go('/map')
                                : next,
                            child: Text(
                              finished
                                  ? 'Продолжить путь'
                                  : checked
                                  ? 'Дальше'
                                  : 'Проверить',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
