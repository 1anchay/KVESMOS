import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/beacon_repository.dart';
import 'character_moment.dart';

/// The chapter records its location. Lesson XP and loot belong to the usual
/// completion flow, including when the learner revisits the shore.
class BeaconChapter extends ConsumerStatefulWidget {
  const BeaconChapter({super.key});
  @override
  ConsumerState<BeaconChapter> createState() => _BeaconChapterState();
}

class _BeaconChapterState extends ConsumerState<BeaconChapter> {
  int? stage;
  String target = '';
  bool saving = false;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final app = ref.read(appProvider);
    try {
      final saved = await BeaconRepository(
        app.repository,
      ).read((app.courseStart.next ?? app.repository.catalog.first).id);
      if (mounted) {
        setState(() {
          stage = saved.stage;
          target = saved.target;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> advance() async {
    if (saving) return;
    final current = stage!;
    final app = ref.read(appProvider);
    if (current == 5) {
      context.go('/rewards');
      return;
    }
    setState(() => saving = true);

    try {
      final saved = await BeaconRepository(
        app.repository,
      ).advance(BeaconState(current, target));
      final next = saved.stage;
      if (!mounted) return;
      setState(() => stage = next);
      if (next == 3) {
        if (!app.installed.contains(target)) {
          context.go('/offline?lesson=$target');
        } else {
          context.go('/lesson/$target?chapter=beacon');
        }
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = stage;
    if (failed) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: load,
            child: const Text('Открыть экспедицию повторно'),
          ),
        ),
      );
    }
    if (current == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final (room, actor, location, line, action) = switch (current) {
      0 => (
        'painted_bridge',
        'orbi',
        'Командный мостик',
        'Слышишь сигнал? Прибрежный маяк ждёт ответа. Пойдём к Мико.',
        'В обсерваторию',
      ),
      1 => (
        'observatory',
        'miko',
        'Обсерватория',
        'Вот источник сигнала. Я проложил курс к посадочной площадке у моря.',
        'Лететь к маяку',
      ),
      2 || 3 => (
        'beacon_shore',
        'orbi',
        'Берег маяка',
        'Чтобы маяк принял передачу, пройди свою учебную миссию. Я помогу с ответами.',
        'Начать передачу',
      ),
      4 => (
        'beacon_shore',
        'miko',
        'Маяк на связи',
        'Передача принята. Смотри, огонь маяка виден даже с корабля!',
        'Вернуться на корабль',
      ),
      _ => (
        'painted_bridge',
        'pixie',
        'С возвращением!',
        'Сигнал сохранён в журнале экспедиции. Посмотрим, что уже есть в твоей коллекции?',
        'К моим находкам',
      ),
    };
    final motion =
        ref.watch(appProvider).audio.preferences.reactions &&
        !MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Первый сигнал'),
        leading: IconButton(
          tooltip: 'На мостик',
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: motion
                    ? const Duration(milliseconds: 450)
                    : Duration.zero,
                child: Stack(
                  key: ValueKey(room),
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/kvesmos/scenes/$room.webp',
                      fit: BoxFit.cover,
                      alignment: room == 'observatory'
                          ? const Alignment(.45, 0)
                          : Alignment.center,
                    ),
                    Positioned(
                      left: 18,
                      bottom: 12,
                      child: actor == 'orbi' && motion
                          ? TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 1050),
                              curve: Curves.easeOutCubic,
                              tween: Tween(begin: 1.0, end: 0.0),
                              builder: (context, approach, _) =>
                                  Transform.translate(
                                    offset: Offset(
                                      76 * approach,
                                      -34 * approach,
                                    ),
                                    child: approach > 0
                                        ? SizedBox(
                                            width: 145,
                                            height: 147,
                                            child: Image.asset(
                                              'assets/kvesmos/crew_motion/orbi_visor_flight.webp',
                                              alignment: Alignment.bottomLeft,
                                              semanticLabel: 'Орби подлетает',
                                            ),
                                          )
                                        : const CharacterMoment(
                                            characterId: 'orbi',
                                            size: 125,
                                          ),
                                  ),
                            )
                          : CharacterMoment(
                              characterId: actor,
                              size: 125,
                              animate: motion,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      location,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(line, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: saving ? null : advance,
                      child: Text(action),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
