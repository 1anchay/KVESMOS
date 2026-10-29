import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/adventures_repository.dart';
import '../domain/space_adventures.dart';
import '../services/learning_audio.dart';
import 'character_moment.dart';
import 'space_station.dart';
import 'optional_adventures.dart';

class SpaceAdventurePage extends ConsumerStatefulWidget {
  final String id;
  const SpaceAdventurePage({super.key, required this.id});
  @override
  ConsumerState<SpaceAdventurePage> createState() => _SpaceAdventurePageState();
}

class _SpaceAdventurePageState extends ConsumerState<SpaceAdventurePage> {
  late final adventure = SpaceAdventure.byId(widget.id);
  late final app = ref.read(appProvider);
  late final repository = AdventuresRepository(app.repository);
  AdventureState? state;
  bool busy = false;
  String? problem, audioProblem;
  final panel = GlobalKey();
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final value = await repository.read(adventure.id);
      if (mounted) {
        setState(() {
          state = value;
          problem = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => problem = '$e');
    }
  }

  Future<void> act(
    String action, {
    String value = '',
    double? x,
    double? y,
  }) async {
    if (busy || state == null) return;
    setState(() {
      busy = true;
      problem = null;
    });
    try {
      final previous = state!;
      final result = await repository.act(
        adventure,
        previous.revision,
        action,
        value: value,
        x: x,
        y: y,
      );
      if (action == 'submit') await app.refresh();
      if (!mounted) return;
      setState(() {
        state = result;
        audioProblem = null;
      });
      if (result.step != previous.step && scroll.hasClients) {
        scroll.jumpTo(0);
      }
      if (action == 'submit') {
        unawaited(
          app.audio.play(
            result.completed
                ? SoundEffect.chapter
                : result.step > previous.step
                ? SoundEffect.pickup
                : SoundEffect.incorrect,
          ),
        );
      } else if (action == 'move') {
        unawaited(app.audio.play(SoundEffect.interact));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => problem =
              'Не удалось завершить сохранение. Повтори попытку: уже записанное действие не начислит XP повторно.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> voice(AdventureStep step, bool slow) async {
    final ok = await app.audio.speak(
      step.english,
      character: adventure.guide,
      slow: slow,
    );
    if (mounted) {
      setState(
        () => audioProblem = ok
            ? null
            : '${app.audio.lastProblem ?? "Голос недоступен."} Читай фразу выше — все действия доступны.',
      );
    }
  }

  @override
  void dispose() {
    unawaited(app.audio.stop());
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final quiet =
        MediaQuery.disableAnimationsOf(context) ||
        !app.audio.preferences.reactions;
    final s = state;
    final unlocked = adventure.unlocked(
      ref.watch(appProvider).progress.completed,
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'На карту, прогресс сохранён',
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/map'),
        ),
        title: const Text('Space Adventures'),
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: SkipAdventureButton(),
        ),
      ),
      body: SafeArea(
        child: s == null
            ? Center(
                child: problem == null
                    ? const CircularProgressIndicator()
                    : Text(problem!),
              )
            : !unlocked
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Сначала пройди уроки: ${adventure.prerequisites.join(", ")}. Приключение ждёт на карте.',
                  ),
                ),
              )
            : ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  Text(adventure.title, style: type.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    s.completed
                        ? 'ЭКСПЕДИЦИЯ ЗАВЕРШЕНА'
                        : 'ШАГ ${s.step + 1} / ${adventure.steps.length} · сохранение автоматически',
                    style: type.labelSmall,
                  ),
                  const SizedBox(height: 12),
                  if (s.completed)
                    ..._completion(s, quiet)
                  else ...[
                    Text(
                      adventure.steps[s.step].title,
                      style: type.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    SpaceStation(
                      adventure: adventure,
                      state: s,
                      quiet: quiet,
                      busy: busy,
                      move: (id, x, y) => act('move', value: id, x: x, y: y),
                    ),
                    const SizedBox(height: 10),
                    // Equivalent movement controls for screen readers and large text.
                    OutlinedButton.icon(
                      key: const Key('approach'),
                      onPressed: busy
                          ? null
                          : () async {
                              await act(
                                'move',
                                value: adventure.steps[s.step].target,
                                x: .5,
                                y: .6,
                              );
                              if (mounted && panel.currentContext != null) {
                                unawaited(
                                  Scrollable.ensureVisible(
                                    panel.currentContext!,
                                    duration: quiet
                                        ? Duration.zero
                                        : const Duration(milliseconds: 250),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.near_me_outlined),
                      label: Text(
                        'Подойти: ${objectName(adventure.steps[s.step].target)}',
                      ),
                    ),
                    ..._interaction(s, type),
                  ],
                  if (problem != null)
                    Semantics(liveRegion: true, child: Text(problem!)),
                ],
              ),
      ),
    );
  }

  List<Widget> _interaction(AdventureState s, TextTheme type) {
    final step = adventure.steps[s.step];
    final near = s.focus == step.target;
    return [
      const SizedBox(height: 8),
      Container(
        key: panel,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SpeakingCharacter(
                  audio: app.audio,
                  character: adventure.guide,
                  size: 52,
                  state: s.dialogue.startsWith('Попробуем')
                      ? CharacterState.support
                      : CharacterState.listening,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(step.english, style: type.headlineSmall)),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  key: const Key('adventure-voice'),
                  onPressed: () => voice(step, false),
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Слушать'),
                ),
                TextButton(
                  onPressed: () => voice(step, true),
                  child: const Text('Медленно'),
                ),
                TextButton(
                  key: const Key('adventure-hint'),
                  onPressed: busy ? null : () => act('hint'),
                  child: const Text('Подсказка'),
                ),
              ],
            ),
            if (audioProblem != null)
              Text(audioProblem!, style: type.bodySmall),
            if ((!step.assessed || s.hint) &&
                !s.dialogue.startsWith('Попробуем'))
              Text(step.explanation),
            if (s.dialogue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Semantics(
                  liveRegion: true,
                  child: Text(s.dialogue, key: const Key('adventure-feedback')),
                ),
              ),
            if (!near)
              const Text(
                'Коснись предмета в комнате или нажми «Подойти», чтобы взаимодействовать.',
              )
            else ...[
              if (step.action == AdventureAction.inspect)
                FilledButton(
                  key: const Key('adventure-submit'),
                  onPressed: busy ? null : () => act('submit'),
                  child: Text(
                    ['book', 'pen', 'bag'].contains(step.target)
                        ? 'Взять в набор'
                        : 'Прочитано · продолжить',
                  ),
                ),
              if ([
                AdventureAction.dialogue,
                AdventureAction.route,
              ].contains(step.action))
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in step.options)
                      FilledButton.tonal(
                        key: ValueKey('answer-$option'),
                        onPressed: busy
                            ? null
                            : () => act('submit', value: option),
                        child: Text(
                          step.action == AdventureAction.route
                              ? '→ $option'
                              : option,
                        ),
                      ),
                  ],
                ),
              if (step.action == AdventureAction.assemble) ...[
                Text(
                  s.tiles.isEmpty ? 'Сигнал: …' : s.tiles.join(' '),
                  key: const Key('signal-tiles'),
                  style: type.titleLarge,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final tile in step.options)
                      OutlinedButton(
                        key: ValueKey('tile-$tile'),
                        onPressed: busy || s.tiles.contains(tile)
                            ? null
                            : () => act('tile', value: tile),
                        child: Text(tile),
                      ),
                  ],
                ),
                TextButton(
                  onPressed: busy ? null : () => act('clear'),
                  child: const Text('Собрать заново'),
                ),
                FilledButton(
                  key: const Key('adventure-submit'),
                  onPressed: busy || s.tiles.length != step.options.length
                      ? null
                      : () => act('submit'),
                  child: const Text('Передать сигнал'),
                ),
              ],
              if (step.action == AdventureAction.cargo) ...[
                const Text('Перетащи вещь на ярлык или выбери её нажатием.'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in s.found)
                      Draggable<String>(
                        data: item,
                        maxSimultaneousDrags: busy ? 0 : 1,
                        feedback: Material(
                          color: stationGold,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Icon(cargoIcon(item), color: stationInk),
                          ),
                        ),
                        child: ChoiceChip(
                          key: ValueKey('cargo-$item'),
                          selected: s.selection == item,
                          onSelected: busy
                              ? null
                              : (_) => act('select', value: item),
                          avatar: Icon(cargoIcon(item)),
                          label: Text(objectName(item)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                DragTarget<String>(
                  onWillAcceptWithDetails: (_) => !busy,
                  onAcceptWithDetails: (details) =>
                      act('submit', value: details.data),
                  builder: (_, candidates, _) => Container(
                    key: const Key('cargo-target'),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: candidates.isEmpty
                          ? stationInk
                          : const Color(0xFF225A56),
                      border: Border.all(color: stationMint, width: 2),
                    ),
                    child: Text(
                      step.english,
                      textAlign: TextAlign.center,
                      style: type.headlineSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  key: const Key('adventure-submit'),
                  onPressed: busy || s.selection.isEmpty
                      ? null
                      : () => act('submit', value: s.selection),
                  child: const Text('Положить в отсек'),
                ),
              ],
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _completion(AdventureState s, bool quiet) => [
    Center(
      child: CharacterMoment(
        characterId: 'orbi',
        state: CharacterState.celebration,
        size: 130,
        animate: !quiet,
      ),
    ),
    Text(
      adventure.outcome,
      style: Theme.of(context).textTheme.titleLarge,
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 16),
    Text(
      'Печать станции получена · ${adventure.xp} XP за освоенные действия. При повторении новые XP не начисляются.',
    ),
    const SizedBox(height: 14),
    for (final line in adventure.recap)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(line)),
          ],
        ),
      ),
    if (s.errors.isNotEmpty) ...[
      const Text(
        'Что потренировать ещё',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      for (final step in adventure.steps.where(
        (step) => s.errors.containsKey(step.id),
      ))
        Text('${step.english} · ${step.explanation}'),
    ],
    const SizedBox(height: 16),
    FilledButton(
      onPressed: () => context.go('/map'),
      child: const Text('К следующему уроку'),
    ),
    OutlinedButton(
      onPressed: () => context.go('/rewards'),
      child: const Text('Мои награды'),
    ),
    TextButton(
      key: const Key('adventure-replay'),
      onPressed: busy ? null : () => act('replay'),
      child: const Text('Сыграть ещё раз'),
    ),
  ];
}
