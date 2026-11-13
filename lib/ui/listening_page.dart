import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/controller.dart';
import '../data/listening_repository.dart';
import '../services/learning_audio.dart';
import 'character_moment.dart';
import 'design.dart';
import 'flight_components.dart';
import 'lesson_effects.dart';

class ListeningPage extends ConsumerStatefulWidget {
  final String? sceneId;
  final bool repeat;
  const ListeningPage({super.key, this.sceneId, this.repeat = false});
  @override
  ConsumerState<ListeningPage> createState() => _ListeningPageState();
}

class _ListeningPageState extends ConsumerState<ListeningPage> {
  late final app = ref.read(appProvider);
  late final audio = app.audio;
  List<ListeningScene>? scenes;
  ListeningRepository? repository;
  Map<String, dynamic>? state;
  String? problem;
  bool loading = true, busy = false, playing = false;
  int playback = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final raw = await app.repository.loadAsset(
        'assets/learning/listening.txt',
      );
      final available = ListeningScene.parse(
        raw,
      ).where((scene) => scene.language == app.course.language).toList();
      final scene = available.where((s) => s.id == widget.sceneId).firstOrNull;
      if (widget.sceneId != null && scene == null) {
        throw StateError('Unknown scene');
      }
      final opened = scene == null
          ? null
          : ListeningRepository(app.repository, scene);
      var value = await opened?.open();
      if (widget.repeat &&
          value?['index'] == scene?.questions.length &&
          opened != null) {
        value = await opened.open(restart: true);
      }
      if (!mounted) return;
      setState(() {
        scenes = available;
        repository = opened;
        state = value;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          problem = 'Не удалось открыть аудиодиалог.';
        });
      }
    }
  }

  Future<void> _change(Future<Map<String, dynamic>> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final value = await action();
      if (mounted) setState(() => state = value);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Не удалось сохранить результат. Попробуй ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _play(bool slow) async {
    final ticket = ++playback;
    setState(() {
      playing = true;
      problem = null;
    });
    final course = app.course;
    for (final line in repository!.scene.lines) {
      final ok = await audio.speakThrough(
        line.line.text,
        character: line.character,
        locale: course.locale,
        slow: slow,
      );
      if (!mounted || ticket != playback) return;
      if (!ok) {
        setState(() {
          playing = false;
          problem =
              audio.lastProblem ??
              'Звук прервался. Можно повторить или перейти к чтению.';
        });
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted || ticket != playback) return;
    }
    setState(() => playing = false);
    await _change(() => repository!.source(heard: true));
  }

  Future<void> _read() async {
    playback++;
    setState(() => playing = false);
    await audio.stop();
    if (mounted) await _change(() => repository!.source(reading: true));
  }

  Future<void> _answer(int index, String option) async {
    await _change(() => repository!.answer(index, option));
    if (!mounted || state?['checked'] != true) return;
    await app.refresh();
    if (mounted) {
      unawaited(
        audio.play(
          state!['correct'] == true
              ? SoundEffect.correct
              : SoundEffect.incorrect,
        ),
      );
    }
  }

  @override
  void dispose() {
    playback++;
    unawaited(audio.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final scene = repository?.scene;
    final value = state;
    final index = value?['index'] as int? ?? 0;
    final question = scene?.questions.elementAtOrNull(index);
    final reading = value?['reading'] == true;
    final checked = value?['checked'] == true;
    final correct = value?['correct'] == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Аудиодиалоги'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.go(scene == null ? '/training' : '/listening'),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : pageBody([
              if (scene == null) ...[
                Text(app.course.name, style: type.titleMedium),
                Text('Поймай смысл на слух', style: type.headlineSmall),
                const Text(
                  'Послушай короткий разговор экипажа и ответь на два вопроса. Текст можно открыть в любой момент.',
                ),
                for (final item in scenes ?? const <ListeningScene>[])
                  FlightPanel(
                    child: ListTile(
                      leading: const Icon(Icons.headphones),
                      title: Text(item.title),
                      subtitle: Text('${item.lines.length} реплики'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/listening/${item.id}'),
                    ),
                  ),
              ] else ...[
                CharacterMoment(
                  characterId: 'miko',
                  state: checked
                      ? (correct
                            ? CharacterState.correct
                            : CharacterState.support)
                      : CharacterState.thinking,
                  animate: checked && audio.preferences.reactions,
                  size: 70,
                ),
                Text(scene.title, style: type.headlineSmall),
                if (question == null) ...[
                  Text('Разговор разобран', style: type.titleLarge),
                  Text(
                    'С первого раза: ${value!['score']} из ${scene.questions.length}.',
                  ),
                  if (reading)
                    const Text(
                      'Часть разговора открыта для чтения. Ответы с текстом не попадают в статистику аудирования.',
                    ),
                  FilledButton(
                    onPressed: () => context.go('/training'),
                    child: const Text('К тренировкам'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _change(() => repository!.open(restart: true)),
                    child: const Text('Пройти ещё раз'),
                  ),
                ] else ...[
                  LessonProgress(done: index, total: scene.questions.length),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: busy || playing ? null : () => _play(false),
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('Послушать'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy || playing ? null : () => _play(true),
                        icon: const Icon(Icons.slow_motion_video),
                        label: const Text('Медленно'),
                      ),
                      if (playing)
                        TextButton(
                          onPressed: () {
                            playback++;
                            unawaited(audio.stop());
                            setState(() => playing = false);
                          },
                          child: const Text('Остановить'),
                        ),
                    ],
                  ),
                  if (playing) const LinearProgressIndicator(),
                  if (!reading)
                    TextButton(
                      onPressed: busy ? null : _read,
                      child: Text(
                        problem == null
                            ? 'Открыть текст'
                            : 'Продолжить чтением',
                      ),
                    ),
                  if (reading)
                    FlightPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Режим чтения', style: type.titleMedium),
                          for (final line in scene.lines)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                [
                                  line.line.text,
                                  if (line.line.pronunciation != null)
                                    line.line.pronunciation!,
                                  if (checked) line.line.meaning,
                                ].join('\n'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (!playing && (value!['heard'] == true || reading)) ...[
                    const SizedBox(height: 12),
                    Text(question.prompt, style: type.titleLarge),
                    for (final option in question.options)
                      OutlinedButton(
                        onPressed: busy || checked || playing
                            ? null
                            : () => _answer(index, option),
                        child: Text(option),
                      ),
                  ] else if (!playing)
                    const Text('После прослушивания появится первый вопрос.'),
                  if (checked) ...[
                    Semantics(
                      liveRegion: true,
                      child: FlightPanel(
                        accent: true,
                        child: Text(
                          '${correct ? 'Верно!' : 'Вот подсказка.'} ${question.explanation}',
                        ),
                      ),
                    ),
                    if (!correct)
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => _change(
                                () => repository!.advance(index, retry: true),
                              ),
                        child: const Text('Попробовать снова'),
                      ),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () => _change(() => repository!.advance(index)),
                      child: const Text('Дальше'),
                    ),
                  ],
                ],
              ],
              if (problem != null)
                Semantics(liveRegion: true, child: Text(problem!)),
            ]),
    );
  }
}
