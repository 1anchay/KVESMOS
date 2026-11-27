import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../core/controller.dart';
import '../data/first_flight_repository.dart';
import '../data/fishing_repository.dart';
import '../data/knowledge_repository.dart';
import '../data/story_repository.dart';
import '../domain/fishing.dart';
import '../domain/fishing_story.dart';
import '../domain/knowledge.dart';
import '../domain/story_dialogue.dart';
import '../services/learning_audio.dart';
import 'fishing_art.dart';
import 'fishing_panels.dart';
import 'flight_ui.dart';
import 'knowledge_widgets.dart';
import 'story_dialogue_sheet.dart';

class FishingDeparturePage extends ConsumerStatefulWidget {
  const FishingDeparturePage({super.key});
  @override
  ConsumerState<FishingDeparturePage> createState() => _DepartureState();
}

class _DepartureState extends ConsumerState<FishingDeparturePage> {
  late final app = ref.read(appProvider);
  late final stories = StoryRepository(app.repository);
  late final language = LanguageContext(
    KnowledgeRepository(app.repository),
    app.audio,
  );
  late Future<(bool, StorySave, FishingSave)> manifest = load();

  Future<(bool, StorySave, FishingSave)> load() async {
    final flight = await FirstFlightRepository(app.repository).read();
    return (
      flight.complete,
      await stories.read(),
      await FishingRepository(app.repository).read(),
    );
  }

  void refreshManifest() {
    final updated = load();
    setState(() {
      manifest = updated;
    });
  }

  Future<void> briefing() async {
    await language.refresh();
    if (!mounted) return;
    await showStoryDialogue(context, FishingStory.briefing, stories, language);
    if (mounted) refreshManifest();
  }

  Future<void> previousReport(FishingSave save, String trip) async {
    final items = save.forTrip(trip);
    await language.refresh();
    if (!mounted) return;
    await showStoryDialogue(
      context,
      fishingReportScene(items),
      stories,
      language,
      contextLine: fishingReportLine(items),
    );
    if (mounted) refreshManifest();
  }

  @override
  void dispose() {
    language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = FlightPalette.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Вылет на Нерею')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: FutureBuilder(
            future: manifest,
            builder: (context, state) {
              if (state.hasError) {
                return TextButton(
                  onPressed: refreshManifest,
                  child: const Text('Повторить загрузку маршрута'),
                );
              }
              final data = state.data;
              if (data == null) return const CircularProgressIndicator();
              final (ready, story, fishing) = data;
              final invited =
                  story.runs[FishingStory.briefing.id]?.finished == true;
              return SafeArea(
                top: false,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 1.4,
                        child: Image.asset(
                          nereyaArt,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Озеро под лунным кольцом',
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ready
                          ? invited
                                ? story.trust(StorySpeaker.pixie) > 0
                                      ? 'Пикси ждёт у озера. Возьми снасти и возвращайся на Нерею.'
                                      : 'Маршрут уже в навигаторе. Сядем у тихих зарослей на западном берегу.'
                                : 'Пикси выходит на связь с мостика. После ремонта она предлагает короткую экспедицию на водную планету.'
                          : 'Сначала восстанови питание и запусти навигацию в первом полёте.',
                    ),
                    const SizedBox(height: 18),
                    if (ready && !invited)
                      FilledButton.icon(
                        key: const Key('fishing-briefing'),
                        style: c.filled,
                        onPressed: briefing,
                        icon: const Icon(Icons.sensors_outlined),
                        label: const Text('Ответить Пикси'),
                      ),
                    if (ready && invited)
                      FilledButton.icon(
                        key: const Key('fishing-depart'),
                        style: c.filled,
                        onPressed: () => context.pushReplacement('/fishing'),
                        icon: const Icon(Icons.rocket_launch_outlined),
                        label: Text(
                          fishing.activeTrip == null
                              ? 'Вылететь на Нерею'
                              : 'Продолжить экспедицию',
                        ),
                      ),
                    if (ready && invited && fishing.lastReport != null)
                      TextButton(
                        key: const Key('fishing-previous-report'),
                        onPressed: () =>
                            previousReport(fishing, fishing.lastReport!),
                        child: const Text('Сводка прошлого вылета'),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _FishingMenu { gear, collection, words, settings, finish, ship }

class FishingPage extends ConsumerStatefulWidget {
  const FishingPage({super.key});
  @override
  ConsumerState<FishingPage> createState() => _FishingPageState();
}

class _FishingPageState extends ConsumerState<FishingPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final app = ref.read(appProvider);
  late final repository = FishingRepository(app.repository);
  late final stories = StoryRepository(app.repository);
  late final language = LanguageContext(
    KnowledgeRepository(app.repository),
    app.audio,
  );
  final game = FishingGame();
  late final Ticker ticker;
  ModalRoute<dynamic>? route;
  Duration? clock;
  Duration drawnAt = Duration.zero;
  FishingSave? save;
  FishingCatch? landed;
  String? trip, attempt, problem;
  bool active = true,
      manualPause = false,
      saving = false,
      permitted = true,
      leaving = false;
  bool strainSound = false;
  double lastStrain = -5;
  int covers = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ticker = createTicker(tick)..start();
    unawaited(load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    route = ModalRoute.of(context);
  }

  Future<void> load() async {
    try {
      final story = await stories.read();
      if (story.runs[FishingStory.briefing.id]?.finished != true) {
        if (mounted) setState(() => permitted = false);
        return;
      }
      final next = await repository.depart(const Uuid().v4());
      await language.refresh();
      if (!mounted) return;
      setState(() {
        useSave(next);
        trip = next.activeTrip;
        problem = null;
      });
    } catch (_) {
      if (mounted) setState(() => problem = 'Не удалось открыть экспедицию.');
    }
  }

  void useSave(FishingSave next) {
    save = next;
    game.rod = next.rod;
    game.bait = next.bait;
    game.comfort = next.comfort;
    game.tuned = next.level > 0;
  }

  void syncPause() {
    if (manualPause || covers > 0 || !active || route?.isCurrent == false) {
      game.pause();
    } else {
      game.resume();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    clock = null;
    syncPause();
  }

  Future<T?> over<T>(Future<T?> Function() show) async {
    covers++;
    syncPause();
    try {
      return await show();
    } finally {
      covers--;
      clock = null;
      syncPause();
    }
  }

  void tick(Duration elapsed) {
    final before = clock;
    clock = elapsed;
    syncPause();
    if (before == null ||
        game.paused ||
        save == null ||
        game.phase == FishingPhase.finished) {
      return;
    }
    final phase = game.phase;
    final age = elapsed - before;
    game.advance(
      age > const Duration(milliseconds: 70)
          ? const Duration(milliseconds: 70)
          : age,
    );
    if (phase != game.phase) transition(game.phase);
    if (game.phase == FishingPhase.fighting) {
      if (game.dangerous && !strainSound && game.elapsed - lastStrain > 1.1) {
        lastStrain = game.elapsed;
        unawaited(app.audio.play(SoundEffect.tension));
      }
      strainSound = game.dangerous;
    }
    if (phase != game.phase ||
        elapsed - drawnAt >= const Duration(milliseconds: 42)) {
      drawnAt = elapsed;
      setState(() {});
    }
  }

  void transition(FishingPhase phase) {
    if (phase == FishingPhase.caught) {
      unawaited(land());
      return;
    }
    final cue = switch (phase) {
      FishingPhase.charging || FishingPhase.hooked => SoundEffect.line,
      FishingPhase.casting => SoundEffect.cast,
      FishingPhase.waiting => SoundEffect.splash,
      FishingPhase.bite => SoundEffect.bite,
      FishingPhase.fighting => SoundEffect.reel,
      FishingPhase.escaped => SoundEffect.escapeFish,
      _ => null,
    };
    if (cue != null) unawaited(app.audio.play(cue));
  }

  void action(void Function() run) {
    syncPause();
    if (saving || game.paused) return;
    final phase = game.phase;
    setState(run);
    if (phase != game.phase) transition(game.phase);
  }

  void cast() => action(() {
    if (game.phase != FishingPhase.charging) return;
    attempt = const Uuid().v4();
    landed = null;
    problem = null;
    strainSound = false;
    lastStrain = -5;
    game.cast();
  });

  Future<void> land() async {
    if (saving ||
        landed != null ||
        trip == null ||
        attempt == null ||
        game.result?.fish == null) {
      return;
    }
    setState(() {
      saving = true;
      problem = null;
    });
    try {
      final landedFish = await repository.land(trip!, attempt!, game.result!);
      if (!mounted) return;
      setState(() {
        useSave(landedFish.save);
        landed = landedFish.entry;
      });
      unawaited(
        app.audio.play(
          landedFish.entry.record || landedFish.entry.discovery
              ? SoundEffect.recordFish
              : SoundEffect.catchFish,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => problem = 'Улов ещё не записан. Повтори сохранение.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> journal() =>
      over<void>(() => showKnowledgeJournal(context, language));

  Future<void> panel(Widget child) =>
      over<void>(() => showFishingPanel(context, child));

  Future<void> gear() async {
    if (save == null || game.playing) return;
    await panel(
      FishingGear(
        initial: save!,
        repository: repository,
        language: language,
        onSaved: (value) {
          if (mounted) setState(() => useSave(value));
        },
      ),
    );
  }

  Future<void> finish({bool returnToShip = false}) async {
    if (saving || leaving) return;
    if (trip == null) {
      if (returnToShip) context.go('/first-flight');
      return;
    }
    if (game.result?.fish != null && landed == null) {
      await land();
      if (!mounted || landed == null) return;
    }
    if (game.playing) {
      final agreed = await over<bool>(
        () => showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Закончить вылет?'),
            content: const Text(
              'Текущий заброс будет отменён. Весь пойманный улов уже в коллекции.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Остаться'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Закончить'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || agreed != true) return;
    }
    setState(() {
      saving = true;
      problem = null;
    });
    try {
      final next = await repository.finish(trip!);
      if (!mounted) return;
      setState(() {
        useSave(next);
        game.finish();
        manualPause = false;
        leaving = returnToShip;
      });
      ticker.stop();
      if (returnToShip) context.go('/first-flight');
    } catch (_) {
      if (mounted) {
        setState(() => problem = 'Не удалось закрыть вылет. Повтори действие.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  List<FishingCatch> get tripCatches => save?.forTrip(trip ?? '') ?? [];

  Future<void> report() {
    final items = tripCatches;
    return over<void>(
      () => showStoryDialogue(
        context,
        fishingReportScene(items),
        stories,
        language,
        contextLine: fishingReportLine(items),
      ),
    );
  }

  @override
  void dispose() {
    ticker.dispose();
    language.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = FlightPalette.of(context);
    final state = save;
    return PopScope(
      canPop: leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(finish(returnToShip: true));
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Вернуться на корабль',
            onPressed: () => finish(returnToShip: true),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Озеро Нереи', overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              key: const Key('fishing-journal'),
              tooltip: 'Личный словарь',
              onPressed: save == null ? null : journal,
              icon: const Icon(Icons.menu_book_outlined),
            ),
            PopupMenuButton<_FishingMenu>(
              key: const Key('fishing-menu'),
              tooltip: 'Экспедиция',
              enabled: state != null && !saving,
              onSelected: (item) async {
                switch (item) {
                  case _FishingMenu.gear:
                    await gear();
                  case _FishingMenu.collection:
                    await panel(FishingCollection(state!, language));
                  case _FishingMenu.words:
                    await panel(FishingWords(language));
                  case _FishingMenu.settings:
                    await over<void>(() => context.push<void>('/settings'));
                  case _FishingMenu.finish:
                    await finish();
                  case _FishingMenu.ship:
                    await finish(returnToShip: true);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _FishingMenu.gear,
                  enabled: !game.playing,
                  child: const Text('Снасти'),
                ),
                const PopupMenuItem(
                  value: _FishingMenu.collection,
                  child: Text('Атлас Нереи'),
                ),
                const PopupMenuItem(
                  value: _FishingMenu.words,
                  child: Text('Слова экспедиции'),
                ),
                const PopupMenuItem(
                  value: _FishingMenu.settings,
                  child: Text('Настройки'),
                ),
                if (game.phase != FishingPhase.finished)
                  const PopupMenuItem(
                    value: _FishingMenu.finish,
                    child: Text('Завершить вылет'),
                  ),
                const PopupMenuItem(
                  value: _FishingMenu.ship,
                  child: Text('На корабль'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: state == null
              ? Center(
                  child: !permitted || problem != null
                      ? TextButton(
                          onPressed: permitted
                              ? load
                              : () => context.go('/nereya'),
                          child: Text(problem ?? 'Связаться с Пикси'),
                        )
                      : const CircularProgressIndicator(),
                )
              : LayoutBuilder(
                  builder: (context, bounds) {
                    final height = (bounds.maxHeight * .55).clamp(155.0, 540.0);
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 570,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          children: [
                            SizedBox(
                              height: height,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  FishingWater(
                                    game: game,
                                    select: (target) =>
                                        action(() => game.point(target)),
                                  ),
                                  if (game.playing)
                                    Positioned(
                                      left: 8,
                                      bottom: 8,
                                      child: Material(
                                        color: const Color(0xdf1d3144),
                                        shape: const CircleBorder(),
                                        child: IconButton(
                                          color: Colors.white,
                                          key: const Key('fishing-pause'),
                                          tooltip: manualPause
                                              ? 'Продолжить'
                                              : 'Пауза',
                                          onPressed: () {
                                            setState(
                                              () => manualPause = !manualPause,
                                            );
                                            syncPause();
                                          },
                                          icon: Icon(
                                            manualPause
                                                ? Icons.play_arrow
                                                : Icons.pause,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (problem != null)
                              Text(
                                problem!,
                                style: TextStyle(color: c.warning),
                              ),
                            controls(c, state),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget controls(FlightPalette c, FishingSave state) {
    final phase = game.phase;
    final heading = manualPause
        ? 'Пауза'
        : switch (phase) {
            FishingPhase.preparation => 'Снасти у берега',
            FishingPhase.aiming => 'Выбери направление',
            FishingPhase.charging => 'Подбери силу заброса',
            FishingPhase.casting || FishingPhase.flight => 'Приманка в полёте',
            FishingPhase.waiting => 'Следи за поплавком',
            FishingPhase.bite => 'Поклёвка — подсекай!',
            FishingPhase.hooked => 'Рыба на крючке',
            FishingPhase.fighting =>
              game.tension > game.safeMax
                  ? 'Ослабь леску!'
                  : game.tension < game.safeMin
                  ? 'Подтяни леску'
                  : 'Держи натяжение в зелёной зоне',
            FishingPhase.caught => game.result!.fish!.title,
            FishingPhase.escaped => switch (game.result!.escape!) {
              FishingEscape.missed => 'Рыба ушла до подсечки',
              FishingEscape.snapped => 'Леска не выдержала',
              FishingEscape.loose => 'Рыба освободилась',
            },
            FishingPhase.finished => 'Итоги вылета',
          };
    Widget primary(String key, String label, VoidCallback? onPressed) =>
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: Key(key),
            onPressed: onPressed,
            style: c.filled,
            child: Text(label),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: phase != FishingPhase.fighting,
          child: Text(
            heading,
            key: Key('fishing-phase-${phase.name}'),
            style: TextStyle(
              color: c.text,
              fontSize: 19,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 5),
        switch (phase) {
          FishingPhase.preparation => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${state.rod.title} · ${state.bait.title}. '
                'Чем дольше набираешь силу, тем дальше летит приманка.',
              ),
              Wrap(
                spacing: 7,
                runSpacing: 3,
                children: [
                  OutlinedButton(
                    key: const Key('fishing-gear'),
                    onPressed: gear,
                    style: c.outline,
                    child: const Text('Снасти'),
                  ),
                  SizedBox(
                    width: 148,
                    child: AdaptiveTerm(
                      language: language,
                      entry: KnowledgeCatalog.lexicon['en:word:water:liquid']!,
                    ),
                  ),
                ],
              ),
              primary('fishing-aim', 'Взять удочку', () => action(game.aim)),
            ],
          ),
          FishingPhase.aiming => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${game.zone.title}, ${game.zone.habitat}. Коснись озера, чтобы прицелиться.',
              ),
              primary(
                'fishing-charge',
                'Набрать силу',
                () => action(game.charge),
              ),
            ],
          ),
          FishingPhase.charging => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FishingGauge('Сила', game.power, .3, .8, c),
              primary('fishing-cast', 'Забросить', manualPause ? null : cast),
            ],
          ),
          FishingPhase.waiting || FishingPhase.bite => primary(
            'fishing-strike',
            'Подсечь',
            manualPause ? null : () => action(game.strike),
          ),
          FishingPhase.fighting => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FishingGauge(
                'Натяжение',
                game.tension,
                game.safeMin,
                game.safeMax,
                c,
              ),
              _FishingGauge('Подтянуто', game.progress, 0, 1, c),
              Row(
                children: [
                  const Icon(Icons.remove, size: 18),
                  Expanded(
                    child: Slider(
                      key: const Key('fishing-reel'),
                      value: game.pressure,
                      semanticFormatterCallback: (v) =>
                          'Усилие катушки ${(v * 100).round()}%',
                      onChanged: manualPause
                          ? null
                          : (v) => action(() => game.reel(v)),
                    ),
                  ),
                  const Icon(Icons.add, size: 18),
                ],
              ),
            ],
          ),
          FishingPhase.caught => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  FishPortrait(game.result!.fish!, size: 76),
                  Expanded(
                    child: Text(
                      '${fishingMass(game.result!.grams)} · ${game.result!.cm} см · ${game.result!.zone.title}'
                      '${landed?.discovery == true ? '\nНовый вид в атласе' : ''}'
                      '${landed?.record == true ? '\nЛичный рекорд' : ''}',
                    ),
                  ),
                ],
              ),
              if (landed == null)
                primary(
                  'fishing-save-catch',
                  saving ? 'Сохраняем…' : 'Сохранить улов',
                  saving ? null : land,
                )
              else
                attemptActions(c),
            ],
          ),
          FishingPhase.escaped => attemptActions(c),
          FishingPhase.finished => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                fishingReportLine(tripCatches),
                key: const Key('fishing-result'),
              ),
              primary('fishing-report', 'Связаться с Пикси', report),
              OutlinedButton(
                key: const Key('fishing-collection'),
                style: c.outline,
                onPressed: () => panel(FishingCollection(state, language)),
                child: const Text('Открыть атлас'),
              ),
              TextButton(
                key: const Key('fishing-return'),
                onPressed: () => finish(returnToShip: true),
                child: const Text('На корабль'),
              ),
            ],
          ),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }

  Widget attemptActions(FlightPalette c) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      FilledButton(
        key: const Key('fishing-retry'),
        style: c.filled,
        onPressed: () => action(game.aim),
        child: const Text('Новый заброс'),
      ),
      OutlinedButton(
        key: const Key('fishing-finish'),
        style: c.outline,
        onPressed: () => finish(),
        child: const Text('Итоги вылета'),
      ),
    ],
  );
}

class _FishingGauge extends StatelessWidget {
  const _FishingGauge(this.label, this.value, this.low, this.high, this.colors);
  final String label;
  final double value, low, high;
  final FlightPalette colors;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label ${(value * 100).round()}%',
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$label · ${(value * 100).round()}%',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          LayoutBuilder(
            builder: (context, limits) {
              final width = limits.maxWidth;
              return SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.warningSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      left: width * low,
                      width: width * (high - low),
                      top: 0,
                      bottom: 0,
                      child: ColoredBox(
                        color: colors.accent.withValues(alpha: .58),
                      ),
                    ),
                    Positioned(
                      left: (width * value - 3).clamp(0.0, width - 6),
                      width: 6,
                      top: 0,
                      bottom: 0,
                      child: ColoredBox(color: colors.text),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 3),
        ],
      ),
    ),
  );
}
