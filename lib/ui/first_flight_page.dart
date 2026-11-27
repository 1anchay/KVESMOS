import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/first_flight_repository.dart';
import '../domain/first_flight.dart';
import 'character_moment.dart';
import 'first_flight_art.dart';

class RebootHome extends ConsumerStatefulWidget {
  const RebootHome({super.key});

  @override
  ConsumerState<RebootHome> createState() => _RebootHomeState();
}

class _RebootHomeState extends ConsumerState<RebootHome> {
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    return Scaffold(
      backgroundColor: flightInk,
      body: SafeArea(
        child: FutureBuilder(
          future: FirstFlightRepository(app.repository).read(),
          builder: (context, snapshot) {
            final flight = snapshot.data;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'KVESMOS',
                        style: TextStyle(
                          color: flightMint,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: MediaQuery.textScalerOf(context).scale(1) > 1.4
                            ? 114
                            : 210,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: CustomPaint(
                            painter: FlightDeckPainter(
                              FirstFlight()..room = FlightRoom.bridge,
                            ),
                            child: Center(
                              child: SpeakingCharacter(
                                audio: app.audio,
                                character: 'orbi',
                                size: 136,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Первый полёт',
                        style: TextStyle(
                          color: flightText,
                          fontWeight: FontWeight.w900,
                          fontSize: 38,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Сигнал бедствия привёл тебя к кораблю без питания. Поднимись на борт и выясни, кто зовёт на помощь.',
                        style: TextStyle(color: flightText, fontSize: 17),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('reboot-start'),
                        style: _filled,
                        onPressed: flight == null
                            ? null
                            : () async {
                                await context.push('/first-flight');
                                if (mounted) setState(() {});
                              },
                        icon: Icon(
                          flight?.complete == true
                              ? Icons.flag_outlined
                              : Icons.rocket_launch_outlined,
                        ),
                        label: Text(
                          flight?.complete == true
                              ? 'Итоги полёта'
                              : flight?.revision == 0
                              ? 'Подняться на борт'
                              : 'Продолжить полёт',
                        ),
                      ),
                      OutlinedButton(
                        key: const Key('reboot-study'),
                        style: _outlined,
                        onPressed: () => context.go(
                          app.onboarded ? '/study' : app.onboardingRoute,
                        ),
                        child: const Text('Уроки и практика'),
                      ),
                      TextButton(
                        onPressed: () => context.push('/settings'),
                        style: _transparent,
                        child: const Text('Настройки'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final _filled = FilledButton.styleFrom(
  backgroundColor: flightMint,
  foregroundColor: flightInk,
  minimumSize: const Size(0, 48),
);
final _outlined = OutlinedButton.styleFrom(
  foregroundColor: flightText,
  side: const BorderSide(color: Color(0xff708c9d)),
  minimumSize: const Size(0, 48),
);
final _transparent = TextButton.styleFrom(
  foregroundColor: flightMint,
  minimumSize: const Size(0, 44),
);

class FirstFlightPage extends ConsumerStatefulWidget {
  const FirstFlightPage({super.key});
  @override
  ConsumerState<FirstFlightPage> createState() => _FirstFlightPageState();
}

class _FirstFlightPageState extends ConsumerState<FirstFlightPage> {
  late final AppController app;
  late final FirstFlightRepository repository;
  FirstFlight? flight;
  Offset pilot = const Offset(.50, .77);
  FlightItem? selected;
  FlightWord? word;
  bool busy = false, loadError = false, journal = false, hintOn = false;
  bool running = true;
  String? message;
  CharacterState orbi = CharacterState.idle;

  static const _arrival =
      'Ты в аварийном шлюзе. Коснись пола, чтобы идти. Подойди к Орби: нажми на него, чтобы поговорить.';

  @override
  void initState() {
    super.initState();
    app = ref.read(appProvider);
    repository = FirstFlightRepository(app.repository);
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final next = await repository.read();
      if (mounted) {
        setState(() {
          flight = next;
          loadError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loadError = true);
    }
  }

  @override
  void dispose() {
    running = false;
    unawaited(app.audio.stop());
    super.dispose();
  }

  void feedback(String text, [CharacterState reaction = CharacterState.idle]) {
    setState(() {
      message = text;
      orbi = reaction;
    });
  }

  void pronounce(FlightWord target) =>
      unawaited(app.audio.speak(target.english, locale: 'en-US'));

  void brief(FlightWord next, {bool reviewing = false}) {
    setState(() {
      word = next;
      journal = reviewing;
      message = null;
    });
    pronounce(next);
  }

  void speakToOrbi(FirstFlight f) {
    final unlearned = FlightWord.deck(
      f.room,
    ).where((item) => !f.learned.contains(item)).firstOrNull;
    if (unlearned != null) {
      brief(unlearned);
    } else {
      feedback(switch (f.room) {
        FlightRoom.airlock =>
          f.unlocked
              ? 'Ты открыл дверь. За ней мастерская.'
              : 'Ключ в аварийном ящике у левой стены. Ключ останется у тебя после открытия двери.',
        FlightRoom.workshop =>
          f.powered ? 'Рубка получила питание. Поднимись по трапу.' : _help(f),
        FlightRoom.bridge =>
          f.navigable
              ? 'Свет загорелся. Теперь можно нажать кнопку у пульта.'
              : f.reserveRequested
              ? 'Запасная батарея в шкафчике. Подойдёт тот же ключ, которым ты открыл дверь.'
              : 'Навигационному пульту нужна маленькая батарея. Можешь попросить её у меня.',
      }, CharacterState.listening);
    }
  }

  Future<void> action(
    FlightAction action, [
    Object? value,
    String? success,
  ]) async {
    final before = flight!;
    try {
      final result = await repository.act(before.revision, action, value);
      if (!mounted) return;
      final next = result.flight;
      setState(() {
        flight = next;
        message = result.message ?? success;
        orbi = result.message != null
            ? CharacterState.support
            : CharacterState.idle;
        if (next.revision == before.revision) return;
        if (next.room != before.room) {
          pilot = const Offset(.5, .77);
          word = null;
          hintOn = false;
          orbi = CharacterState.greeting;
        }
        if (!next.inventory.contains(selected) ||
            action == FlightAction.unlock && result.message == null) {
          selected = null;
        }
      });
      if (next.revision == before.revision) return;
      if (action == FlightAction.fitReserve) pronounce(FlightWord.press);
      if (action == FlightAction.launch) await app.refresh();
    } catch (_) {
      if (mounted) {
        feedback(
          'Не удалось сохранить действие. Попробуй ещё раз.',
          CharacterState.support,
        );
      }
    }
  }

  Future<void> acknowledge(FlightWord target) async {
    if (busy) return;
    if (journal) {
      setState(() => word = null);
      unawaited(app.audio.stop());
      return;
    }
    setState(() => busy = true);
    try {
      await action(FlightAction.teach, target);
      if (!mounted || !flight!.learned.contains(target)) return;
      final next = FlightWord.deck(
        flight!.room,
      ).where((item) => !flight!.learned.contains(item)).firstOrNull;
      if (next != null) {
        brief(next);
      } else {
        setState(() {
          word = null;
          message = _help(flight!);
        });
        unawaited(app.audio.stop());
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> approach(_Spot spot) async {
    if (busy || word != null) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    setState(() {
      pilot = Offset(spot.at.dx, (spot.at.dy + .13).clamp(.27, .83));
      busy = true;
    });
    try {
      if (!reduced) {
        await Future<void>.delayed(const Duration(milliseconds: 320));
      }
      if (running) await spot.use();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _help(FirstFlight f) {
    if (!f.knowsRoom(f.room)) return _arrivalFor(f.room);
    return switch (f.room) {
      FlightRoom.airlock =>
        f.unlocked
            ? 'Коснись открытой двери. Она ведёт в мастерскую.'
            : f.inventory.contains(FlightItem.key)
            ? 'Коснись ключа в рюкзаке, а затем двери.'
            : 'Открой аварийный ящик и возьми ключ.',
      FlightRoom.workshop =>
        f.powered
            ? 'Коснись трапа, чтобы подняться в рубку.'
            : !f.charged || !f.wired
            ? 'Осмотри контейнер и катушку. Выбирай детали в рюкзаке и применяй к гнезду и разъёмам.'
            : 'Поверни левую стрелку вправо, правую вверх. Затем включи питание.',
      FlightRoom.bridge =>
        f.navigable
            ? 'Нажми на кнопку рядом с горящим светом.'
            : !f.reserveRequested
            ? 'Поговори с Орби и нажми «Попросить батарею».'
            : !f.lockerOpen
            ? 'Выбери ключ в рюкзаке и открой шкафчик.'
            : f.inventory.contains(FlightItem.reserve)
            ? 'Выбери маленькую батарею в рюкзаке и коснись гнезда пульта.'
            : 'Возьми маленькую батарею из открытого шкафчика.',
    };
  }

  String _arrivalFor(FlightRoom room) => switch (room) {
    FlightRoom.airlock => _arrival,
    FlightRoom.workshop =>
      'Это мастерская. Орби нашёл генератор. Поговори с ним у левой стены.',
    FlightRoom.bridge =>
      'Ты в рубке. За стеклом уже видна планета. Орби ждёт у навигационного пульта.',
  };

  List<_Spot> spots(FirstFlight f) {
    _Spot spot(
      String id,
      String label,
      IconData icon,
      double x,
      double y,
      FutureOr<void> Function() use, {
      Color color = flightMint,
      int turn = 0,
      FlightWord? demo,
    }) => _Spot(
      id,
      label,
      icon,
      Offset(x, y),
      use,
      color: color,
      turn: turn,
      demo: demo,
    );
    final orbi = spot(
      'orbi',
      'Орби',
      Icons.smart_toy_outlined,
      .33,
      .43,
      () => speakToOrbi(f),
    );
    return switch (f.room) {
      FlightRoom.airlock => [
        orbi,
        spot(
          'hatch',
          f.unlocked ? 'Мастерская' : 'Дверь',
          f.unlocked
              ? Icons.meeting_room_outlined
              : Icons.door_front_door_outlined,
          .5,
          .21,
          () => f.unlocked
              ? action(FlightAction.travel, FlightRoom.workshop)
              : action(
                  FlightAction.unlock,
                  selected,
                  'Замок открылся. Мастерская за дверью.',
                ),
          demo: FlightWord.door,
        ),
        spot(
          'toolbox',
          f.inventory.contains(FlightItem.key)
              ? 'Пустой ящик'
              : 'Аварийный ящик',
          f.inventory.contains(FlightItem.key)
              ? Icons.inventory_2_outlined
              : Icons.vpn_key_outlined,
          .20,
          .67,
          () => f.inventory.contains(FlightItem.key)
              ? feedback('Ключ уже в рюкзаке.')
              : action(
                  FlightAction.take,
                  FlightItem.key,
                  'Ключ в рюкзаке. Выбери его и коснись двери.',
                ),
          color: flightAmber,
          demo: FlightWord.key,
        ),
        spot(
          'porthole',
          'Окно',
          Icons.language,
          .77,
          .42,
          () => feedback(
            f.powered
                ? 'За стеклом горят огни корабля. В мастерской получилось вернуть питание.'
                : 'Вдалеке светится станция. На борту темно, но воздух в шлюзе есть.',
          ),
        ),
        spot(
          'log',
          'Журнал экипажа',
          Icons.receipt_long,
          .76,
          .72,
          () => feedback(
            'Последняя запись: «Гроза вывела из строя питание. Запасные детали в мастерской».',
          ),
          color: flightAmber,
        ),
      ],
      FlightRoom.workshop => [
        spot(
          'orbi',
          'Орби',
          Icons.smart_toy_outlined,
          .18,
          .47,
          () => speakToOrbi(f),
        ),
        spot(
          'charger',
          f.charged ? 'На питании' : 'Гнездо',
          Icons.battery_charging_full,
          .23,
          .28,
          () => f.charged
              ? feedback('Батарея подаёт питание на цепь.')
              : action(
                  FlightAction.fitBattery,
                  selected,
                  'Батарея подключена. Осталось замкнуть цепь.',
                ),
          demo: FlightWord.battery,
        ),
        spot(
          'sockets',
          f.wired ? 'Соединено' : 'Разъёмы',
          Icons.cable,
          .49,
          .40,
          () => f.wired
              ? feedback('Кабель соединяет разъёмы.')
              : action(
                  FlightAction.fitCable,
                  selected,
                  'Кабель на месте. Веди питание вдоль дорожки.',
                ),
          demo: FlightWord.cable,
        ),
        if (!f.charged && !f.inventory.contains(FlightItem.battery))
          spot(
            'battery',
            'Контейнер',
            Icons.battery_std,
            .73,
            .49,
            () => action(
              FlightAction.take,
              FlightItem.battery,
              'Большая батарея в рюкзаке.',
            ),
            color: flightAmber,
            demo: FlightWord.battery,
          ),
        if (!f.wired && !f.inventory.contains(FlightItem.cable))
          spot(
            'cable',
            'Катушка',
            Icons.cable,
            .81,
            .76,
            () => action(
              FlightAction.take,
              FlightItem.cable,
              'Кабель в рюкзаке.',
            ),
            color: flightAmber,
            demo: FlightWord.cable,
          ),
        spot(
          'turn-a',
          'Левая стрелка',
          Icons.arrow_forward,
          .35,
          .65,
          () => action(FlightAction.turnA),
          turn: f.rotorA,
          color: f.rotorA == 0 ? flightMint : flightAmber,
        ),
        spot(
          'turn-b',
          'Правая стрелка',
          Icons.arrow_forward,
          .66,
          .65,
          () => action(FlightAction.turnB),
          turn: f.rotorB,
          color: f.rotorB == 3 ? flightMint : flightAmber,
        ),
        spot(
          'breaker',
          f.powered ? 'Питание есть' : 'Рубильник',
          Icons.power_settings_new,
          .79,
          .29,
          () => f.powered
              ? feedback('Питание корабля восстановлено.')
              : action(
                  FlightAction.breaker,
                  null,
                  'Корабль ожил. Трап в рубку разблокирован.',
                ),
        ),
        spot(
          'to-bridge',
          'Трап в рубку',
          f.powered ? Icons.stairs : Icons.lock_outline,
          .5,
          .18,
          () => action(FlightAction.travel, FlightRoom.bridge),
        ),
        spot(
          'to-airlock',
          'В шлюз',
          Icons.undo,
          .20,
          .80,
          () => action(FlightAction.travel, FlightRoom.airlock),
        ),
      ],
      FlightRoom.bridge => [
        orbi,
        spot(
          'locker',
          f.lockerOpen ? 'Открыт' : 'Шкафчик',
          f.lockerOpen ? Icons.battery_2_bar : Icons.lock_outline,
          .77,
          .42,
          () async {
            if (!f.lockerOpen) {
              await action(
                FlightAction.unlock,
                selected,
                'Шкафчик открыт. Внутри запасная батарея.',
              );
            } else if (f.inventory.contains(FlightItem.reserve) ||
                f.navigable) {
              feedback('Шкафчик пуст.');
            } else {
              await action(
                FlightAction.take,
                FlightItem.reserve,
                'Маленькая батарея в рюкзаке.',
              );
            }
          },
          color: flightAmber,
          demo: FlightWord.need,
        ),
        spot(
          'nav-socket',
          'Гнездо пульта',
          Icons.battery_charging_full,
          .72,
          .67,
          () => f.navigable
              ? feedback('Запасная батарея питает пульт.')
              : action(
                  FlightAction.fitReserve,
                  selected,
                  'Свет загорелся. Орби: «Нажми на кнопку».',
                ),
          demo: FlightWord.need,
        ),
        spot(
          'lamp',
          f.navigable ? 'Свет горит' : 'Свет погашен',
          f.navigable ? Icons.lightbulb : Icons.lightbulb_outline,
          .50,
          .25,
          () => feedback(
            f.navigable
                ? 'Индикатор горит. Пульт готов к запуску.'
                : 'Индикатор тёмный. Пульту нужно питание.',
          ),
          color: f.navigable ? flightMint : flightAmber,
          demo: FlightWord.light,
        ),
        spot(
          'launch',
          'Кнопка пуска',
          Icons.radio_button_checked,
          .21,
          .65,
          () => action(FlightAction.launch),
          color: f.navigable ? flightMint : flightAmber,
          demo: word == FlightWord.press ? FlightWord.press : FlightWord.button,
        ),
        spot(
          'to-workshop',
          'В мастерскую',
          Icons.undo,
          .24,
          .83,
          () => action(FlightAction.travel, FlightRoom.workshop),
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final f = flight;
    return Scaffold(
      backgroundColor: flightInk,
      appBar: AppBar(
        backgroundColor: flightInk,
        foregroundColor: flightText,
        leading: IconButton(
          tooltip: 'На главный экран',
          icon: const Icon(Icons.arrow_back),
          onPressed: goHome,
        ),
        title: Text(f?.room.title ?? 'Первый полёт'),
        actions: [
          if (f != null && f.learned.isNotEmpty && !f.complete)
            IconButton(
              key: const Key('flight-journal'),
              tooltip: 'Слова',
              onPressed: () => showJournal(f),
              icon: const Icon(Icons.menu_book_outlined),
            ),
          if (f != null && !f.complete)
            IconButton(
              key: const Key('flight-help'),
              tooltip: 'Подсказка',
              onPressed: () => setState(() => hintOn = !hintOn),
              icon: const Icon(Icons.help_outline),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: f == null
            ? Center(
                child: loadError
                    ? TextButton(
                        style: _transparent,
                        onPressed: load,
                        child: const Text('Не удалось загрузить. Повторить'),
                      )
                    : const CircularProgressIndicator(color: flightMint),
              )
            : Align(
                alignment: f.complete ? Alignment.center : Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: f.complete ? ending() : play(f),
                ),
              ),
      ),
    );
  }

  Widget play(FirstFlight f) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            f.objective,
            style: const TextStyle(
              color: flightText,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: scene(f)),
        const SizedBox(height: 10),
        if (word case final target?)
          lesson(target)
        else ...[
          info(
            message ??
                (!f.knowsRoom(f.room) ? _arrivalFor(f.room) : f.objective),
          ),
          if (f.room == FlightRoom.bridge &&
              f.knowsRoom(f.room) &&
              !f.reserveRequested)
            TextButton.icon(
              key: const Key('flight-request'),
              style: _transparent,
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        pronounce(FlightWord.need);
                        await action(
                          FlightAction.requestReserve,
                          null,
                          'Орби: «Запасная батарея в шкафчике. Его откроет тот же ключ, что и дверь в мастерскую».',
                        );
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Попросить батарею · I need a battery.'),
            ),
        ],
        if (hintOn)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: info(_help(f), help: true),
          ),
        const SizedBox(height: 10),
        const Text(
          'Рюкзак',
          style: TextStyle(color: flightText, fontWeight: FontWeight.w800),
        ),
        if (f.inventory.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Пока пуст',
              style: TextStyle(color: Color(0xffafc3cc)),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [for (final item in f.inventory) itemChip(item, f)],
          ),
      ],
    ),
  );

  Widget info(String value, {bool help = false}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: flightPanel,
      border: help ? Border.all(color: flightAmber) : null,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      value,
      style: TextStyle(
        color: help ? flightAmber : flightText,
        fontSize: 15,
        height: 1.3,
      ),
    ),
  );

  Widget itemChip(FlightItem item, FirstFlight f) => ChoiceChip(
    key: Key('flight-item-${item.name}'),
    visualDensity: VisualDensity.standard,
    selected: selected == item,
    avatar: Icon(
      _itemIcon(item),
      color: selected == item ? flightInk : flightMint,
      size: 19,
    ),
    label: Text(item.title),
    backgroundColor: flightPanel,
    disabledColor: selected == item ? flightMint : flightPanel,
    selectedColor: flightMint,
    labelStyle: TextStyle(color: selected == item ? flightInk : flightText),
    showCheckmark: false,
    onSelected: busy || word != null
        ? null
        : (on) {
            setState(() {
              selected = on ? item : null;
              message = on
                  ? '${item.title} · ${item.english}. Теперь коснись места, где нужна эта деталь.'
                  : null;
            });
          },
  );

  Widget scene(FirstFlight f) => LayoutBuilder(
    builder: (context, c) {
      final h = (MediaQuery.sizeOf(context).height * .44).clamp(295.0, 420.0);
      final size = Size(c.maxWidth, h);
      final reduced = MediaQuery.disableAnimationsOf(context);
      return SizedBox(
        height: h,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: FlightDeckPainter(f)),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                key: const Key('flight-floor'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (event) {
                  if (busy || word != null) return;
                  setState(
                    () => pilot = Offset(
                      (event.localPosition.dx / size.width).clamp(.15, .85),
                      (event.localPosition.dy / h).clamp(.28, .84),
                    ),
                  );
                },
              ),
            ),
            AnimatedPositioned(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: size.width * pilot.dx - 19,
              top: h * pilot.dy - 17,
              child: IgnorePointer(
                child: CustomPaint(
                  size: const Size(38, 46),
                  painter: FlightPilotPainter(),
                ),
              ),
            ),
            for (final spot in spots(f))
              Positioned(
                left: (size.width * spot.at.dx - 38).clamp(
                  0.0,
                  size.width - 76,
                ),
                top: h * spot.at.dy - (spot.id == 'orbi' ? 36 : 25),
                width: 76,
                child: Semantics(
                  button: true,
                  label: spot.label,
                  onTap: () => approach(spot),
                  child: GestureDetector(
                    excludeFromSemantics: true,
                    key: Key('flight-${spot.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => approach(spot),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (spot.id == 'orbi')
                          IgnorePointer(
                            child: SpeakingCharacter(
                              audio: app.audio,
                              character: 'orbi',
                              state: orbi,
                              size: 67,
                            ),
                          )
                        else
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: word != null && word == spot.demo
                                  ? const [
                                      BoxShadow(
                                        color: flightAmber,
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                    ]
                                  : const [],
                            ),
                            child: FlightProp(
                              spot.icon,
                              turn: spot.turn,
                              color: spot.color,
                            ),
                          ),
                        ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: flightInk,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              spot.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.linear(
                                MediaQuery.textScalerOf(
                                  context,
                                ).scale(1).clamp(1.0, 1.18),
                              ),
                              style: const TextStyle(
                                color: flightText,
                                fontSize: 10.5,
                                height: 1.05,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget lesson(FlightWord t) => DecoratedBox(
    decoration: BoxDecoration(
      color: flightPanel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: flightMint.withValues(alpha: .5)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FlightProp(_wordIcon(t), size: 48, color: flightAmber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.english,
                      style: const TextStyle(
                        color: flightMint,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      t.translation,
                      style: const TextStyle(color: flightText, fontSize: 15),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('flight-pronounce'),
                tooltip: 'Послушать произношение',
                onPressed: () => pronounce(t),
                icon: const Icon(Icons.volume_up, color: flightMint),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.context,
            style: const TextStyle(color: flightText, height: 1.3),
          ),
          const SizedBox(height: 6),
          TextButton(
            key: const Key('flight-understood'),
            style: _transparent,
            onPressed: busy ? null : () => acknowledge(t),
            child: Text(journal ? 'Закрыть' : 'Понятно'),
          ),
        ],
      ),
    ),
  );

  Future<void> showJournal(FirstFlight f) async {
    if (busy) return;
    final chosen = await showModalBottomSheet<FlightWord>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Уже знакомые слова и фразы')),
            for (final w in f.learned)
              ListTile(
                leading: Icon(_wordIcon(w)),
                title: Text(w.english),
                subtitle: Text(w.translation),
                onTap: () => Navigator.pop(context, w),
              ),
          ],
        ),
      ),
    );
    if (mounted && chosen != null) brief(chosen, reviewing: true);
  }

  Widget ending() => ListView(
    padding: const EdgeInsets.all(22),
    shrinkWrap: true,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 230,
          child: CustomPaint(
            painter: FlightDeckPainter(flight!),
            child: Center(
              child: SpeakingCharacter(
                audio: app.audio,
                character: 'orbi',
                state: CharacterState.celebration,
                size: 144,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Корабль готов к полёту',
        key: Key('flight-complete'),
        style: TextStyle(
          color: flightText,
          fontSize: 31,
          height: 1.08,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Двигатели ответили. Орби прокладывает курс к станции, а за стеклом появляются огни взлётной дорожки. Ты вернул кораблю питание и запустил навигацию.',
        style: TextStyle(color: flightText, fontSize: 17),
      ),
      const SizedBox(height: 14),
      info(
        'Награда: сундук исследователя. Он ждёт в разделе «Сундуки».',
        help: true,
      ),
      const SizedBox(height: 14),
      FilledButton(
        key: const Key('flight-home'),
        style: _filled,
        onPressed: goHome,
        child: const Text('На главный экран'),
      ),
      TextButton(
        style: _transparent,
        onPressed: () => context.push('/rewards'),
        child: const Text('Открыть сундуки'),
      ),
    ],
  );

  void goHome() => context.canPop() ? context.pop() : context.go('/');
}

class _Spot {
  const _Spot(
    this.id,
    this.label,
    this.icon,
    this.at,
    this.use, {
    required this.color,
    required this.turn,
    this.demo,
  });
  final String id, label;
  final IconData icon;
  final Offset at;
  final FutureOr<void> Function() use;
  final Color color;
  final int turn;
  final FlightWord? demo;
}

IconData _itemIcon(FlightItem item) => switch (item) {
  FlightItem.key => Icons.vpn_key_outlined,
  FlightItem.battery => Icons.battery_std,
  FlightItem.cable => Icons.cable,
  FlightItem.reserve => Icons.battery_2_bar,
};
IconData _wordIcon(FlightWord word) => switch (word) {
  FlightWord.door => Icons.door_front_door_outlined,
  FlightWord.key => Icons.vpn_key_outlined,
  FlightWord.battery || FlightWord.need => Icons.battery_std,
  FlightWord.cable => Icons.cable,
  FlightWord.light => Icons.lightbulb_outline,
  FlightWord.button || FlightWord.press => Icons.radio_button_checked,
};
