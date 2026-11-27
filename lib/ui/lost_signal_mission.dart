import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/lost_signal_repository.dart';
import '../domain/lost_signal.dart';
import '../services/learning_audio.dart';
import 'character_moment.dart';

class LostSignalMissionPage extends ConsumerStatefulWidget {
  const LostSignalMissionPage({super.key});
  @override
  ConsumerState<LostSignalMissionPage> createState() =>
      _LostSignalMissionPageState();
}

class _LostSignalMissionPageState extends ConsumerState<LostSignalMissionPage> {
  late final app = ref.read(appProvider);
  late final repository = LostSignalRepository(app.repository);
  LostSignalState? state;
  bool busy = false;
  String? problem;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final value = await repository.read();
      if (mounted) setState(() => state = value);
    } catch (error) {
      if (mounted) setState(() => problem = '$error');
    }
  }

  Future<void> _act(String action, {String value = ''}) async {
    final current = state;
    if (busy || current == null) return;
    setState(() {
      busy = true;
      problem = null;
    });
    try {
      final result = await repository.act(
        current.revision,
        action,
        value: value,
      );
      if (action == 'button' || action == 'replay') await app.refresh();
      if (!mounted) return;
      setState(() => state = result);
      final success =
          result.phase > current.phase ||
          result.inventory.length > current.inventory.length;
      if (action != 'hint' && action != 'replay') {
        await app.audio.play(
          result.completed
              ? SoundEffect.chapter
              : success
              ? SoundEffect.pickup
              : action == 'travel'
              ? SoundEffect.interact
              : SoundEffect.incorrect,
        );
      }
      if (result.phase != current.phase && !result.completed) {
        unawaited(
          app.audio.speak(result.objective, character: 'miko', locale: 'en-US'),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => problem =
              'Не удалось сохранить действие. Нажми ещё раз — награда не продублируется.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _voice() =>
      app.audio.speak(state!.objective, character: 'miko', locale: 'en-US');

  @override
  void dispose() {
    unawaited(app.audio.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = state;
    return Scaffold(
      backgroundColor: const Color(0xff081721),
      appBar: AppBar(
        backgroundColor: const Color(0xff102638),
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Покинуть станцию — прогресс сохранён',
          onPressed: () => context.go('/adventures'),
          icon: const Icon(Icons.close),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MISSION 01',
              style: TextStyle(fontSize: 11, letterSpacing: 2),
            ),
            Text('Lost Signal', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
      body: SafeArea(
        child: current == null
            ? Center(
                child: problem == null
                    ? const CircularProgressIndicator()
                    : Text(
                        problem!,
                        style: const TextStyle(color: Colors.white),
                      ),
              )
            : Column(
                children: [
                  _MissionHud(
                    state: current,
                    busy: busy,
                    onVoice: _voice,
                    onHint: () => _act('hint'),
                  ),
                  Expanded(
                    child: _LostSignalScene(
                      state: current,
                      busy: busy,
                      act: _act,
                      audio: app.audio,
                    ),
                  ),
                  _FeedbackStrip(state: current, problem: problem),
                ],
              ),
      ),
    );
  }
}

class _MissionHud extends StatelessWidget {
  final LostSignalState state;
  final bool busy;
  final VoidCallback onVoice, onHint;
  const _MissionHud({
    required this.state,
    required this.busy,
    required this.onVoice,
    required this.onHint,
  });
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xff102638),
    padding: const EdgeInsets.fromLTRB(14, 8, 10, 9),
    child: Row(
      children: [
        const Icon(Icons.track_changes, color: Color(0xff78d8ce)),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'OBJECTIVE',
                style: TextStyle(
                  color: Color(0xff78d8ce),
                  fontSize: 10,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                state.objective,
                key: const Key('lost-signal-objective'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              if (state.hint)
                Text(
                  state.translation,
                  key: const Key('lost-signal-translation'),
                  style: const TextStyle(color: Color(0xffffd494)),
                ),
            ],
          ),
        ),
        IconButton(
          key: const Key('lost-signal-voice'),
          tooltip: 'Прослушать инструкцию',
          onPressed: busy ? null : onVoice,
          color: Colors.white,
          icon: const Icon(Icons.volume_up_rounded),
        ),
        IconButton(
          key: const Key('lost-signal-hint'),
          tooltip: 'Перевод',
          onPressed: busy ? null : onHint,
          color: state.hint ? const Color(0xffffd494) : Colors.white70,
          icon: const Icon(Icons.translate_rounded),
        ),
      ],
    ),
  );
}

class _LostSignalScene extends StatelessWidget {
  final LostSignalState state;
  final bool busy;
  final Future<void> Function(String action, {String value}) act;
  final LearningAudio audio;
  const _LostSignalScene({
    required this.state,
    required this.busy,
    required this.act,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final dock = state.room == 'dock';
      return Stack(
        key: ValueKey('lost-signal-${state.room}-${state.powered}'),
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: Image.asset(
              dock
                  ? 'assets/kvesmos/scenes/observatory.webp'
                  : 'assets/kvesmos/scenes/painted_bridge.webp',
              key: ValueKey(state.room),
              fit: BoxFit.cover,
              cacheWidth: 1536,
            ),
          ),
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              color: state.powered
                  ? const Color(0x0800ffd0)
                  : const Color(0x77020b18),
            ),
          ),
          if (dock) ..._dockObjects(box) else ..._controlObjects(box),
          Positioned(
            left: 10,
            top: 10,
            child: _RoomBadge(
              icon: dock ? Icons.sensor_door_outlined : Icons.memory_rounded,
              label: dock ? 'DOCKING RING' : 'CONTROL ROOM',
            ),
          ),
          if (state.doorOpen)
            Positioned(
              left: 10,
              bottom: 10,
              child: FilledButton.tonalIcon(
                key: Key(dock ? 'travel-control' : 'travel-dock'),
                onPressed: busy
                    ? null
                    : () => act('travel', value: dock ? 'control' : 'dock'),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: Text(dock ? 'Control room' : 'Docking ring'),
              ),
            ),
          if (state.phase == 0) _intro(context),
          if (state.phase == 3) _dialogue(context),
          if (state.completed) _completion(context),
        ],
      );
    },
  );

  List<Widget> _dockObjects(BoxConstraints box) => [
    _place(
      box,
      .08,
      .28,
      .22,
      .52,
      _Door(
        key: const Key('door-red'),
        color: const Color(0xffa94d27),
        label: 'RED',
        onTap: busy || state.phase != 1
            ? null
            : () => act('door', value: 'red'),
      ),
    ),
    _place(
      box,
      .39,
      .19,
      .22,
      .61,
      _Door(
        key: const Key('door-blue'),
        color: const Color(0xff2589c9),
        label: state.doorOpen ? 'OPEN' : 'BLUE',
        open: state.doorOpen,
        onTap: busy
            ? null
            : state.doorOpen
            ? () => act('travel', value: 'control')
            : state.phase == 1
            ? () => act('door', value: 'blue')
            : null,
      ),
    ),
    _place(
      box,
      .70,
      .28,
      .22,
      .52,
      _Door(
        key: const Key('door-yellow'),
        color: const Color(0xffc69532),
        label: 'YELLOW',
        onTap: busy || state.phase != 1
            ? null
            : () => act('door', value: 'yellow'),
      ),
    ),
  ];

  List<Widget> _controlObjects(BoxConstraints box) {
    final collecting = state.phase == 2;
    return [
      if (!state.inventory.contains('red_key'))
        _place(
          box,
          .12,
          .55,
          .17,
          .25,
          _Prop(
            key: const Key('object-red-key'),
            icon: Icons.key_rounded,
            color: const Color(0xffd84e3d),
            label: 'RED KEY',
            onTap: busy || !collecting
                ? null
                : () => act('collect', value: 'red_key'),
          ),
        ),
      if (!state.inventory.contains('battery') && !state.batteryInstalled)
        _place(
          box,
          .40,
          .54,
          .18,
          .27,
          _Prop(
            key: const Key('object-battery'),
            icon: Icons.battery_charging_full_rounded,
            color: const Color(0xffffd05a),
            label: 'BATTERY',
            onTap: busy || !collecting
                ? null
                : () => act('collect', value: 'battery'),
          ),
        ),
      if (collecting)
        _place(
          box,
          .65,
          .59,
          .13,
          .20,
          _Prop(
            key: const Key('object-blue-key'),
            icon: Icons.key_rounded,
            color: const Color(0xff4ea9e8),
            label: 'BLUE KEY',
            dim: state.inspected.contains('blue_key'),
            onTap: busy ? null : () => act('collect', value: 'blue_key'),
          ),
        ),
      _place(
        box,
        .72,
        .23,
        .24,
        .46,
        _PowerUnit(
          installed: state.batteryInstalled,
          powered: state.powered,
          enabled: !busy && state.phase == 4,
          onInstall: () => act('install'),
        ),
      ),
      if (state.phase == 5)
        _place(
          box,
          .27,
          .18,
          .46,
          .22,
          _ButtonPanel(
            busy: busy,
            onTap: (color) => act('button', value: color),
          ),
        ),
    ];
  }

  Widget _intro(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: const Color(0xcc07131e),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpeakingCharacter(
                  audio: audio,
                  character: 'miko',
                  state: CharacterState.surprise,
                  size: 112,
                ),
                const Text(
                  'INCOMING TRANSMISSION',
                  style: TextStyle(
                    color: Color(0xff78d8ce),
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '“We lost contact with Station Echo. Let’s go.”',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  key: const Key('lost-signal-intro-voice'),
                  onPressed: () => audio.speak(
                    'We lost contact with Station Echo. Let’s go.',
                    character: 'miko',
                    locale: 'en-US',
                  ),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Listen'),
                ),
                FilledButton.icon(
                  key: const Key('lost-signal-start'),
                  onPressed: busy ? null : () => act('start'),
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text('Fly to Station Echo'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _dialogue(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: const Color(0x99020b18),
      child: SingleChildScrollView(
        reverse: true,
        padding: const EdgeInsets.all(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xee102638),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xff78d8ce)),
          ),
          child: Row(
            children: [
              SpeakingCharacter(
                audio: audio,
                character: 'miko',
                state: CharacterState.talking,
                size: 78,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'MIKO · Do you have the battery?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final answer in const [
                      'No, I don’t have the battery.',
                      'Yes, I have the battery.',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: OutlinedButton(
                          key: ValueKey('reply-$answer'),
                          onPressed: busy
                              ? null
                              : () => act('reply', value: answer),
                          child: Text(answer),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _completion(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: const Color(0xb3051922),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            constraints: const BoxConstraints(maxWidth: 430),
            decoration: BoxDecoration(
              color: const Color(0xee102d36),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xffffd494), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.satellite_alt_rounded,
                  color: Color(0xffffd494),
                  size: 50,
                ),
                const Text(
                  'SIGNAL RESTORED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Station Echo is online. Reward saved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xffd7f4ef)),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('lost-signal-reward'),
                  onPressed: () => context.go('/rewards'),
                  icon: const Icon(Icons.redeem_rounded),
                  label: const Text('Open mission reward'),
                ),
                TextButton(
                  key: const Key('lost-signal-replay'),
                  onPressed: busy ? null : () => act('replay'),
                  child: const Text('Replay mission'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Positioned _place(
  BoxConstraints box,
  double x,
  double y,
  double width,
  double height,
  Widget child,
) => Positioned(
  left: box.maxWidth * x,
  top: box.maxHeight * y,
  width: box.maxWidth * width,
  height: box.maxHeight * height,
  child: child,
);

class _Door extends StatelessWidget {
  final Color color;
  final String label;
  final bool open;
  final VoidCallback? onTap;
  const _Door({
    super.key,
    required this.color,
    required this.label,
    required this.onTap,
    this.open = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label door',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
            gradient: open
                ? const RadialGradient(
                    colors: [Color(0xff78d8ce), Color(0xff061723)],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: .95),
                      color.withValues(alpha: .42),
                    ],
                  ),
            border: Border.all(color: const Color(0xffffd494), width: 3),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: .65), blurRadius: 18),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                open ? Icons.login_rounded : Icons.lock_outline_rounded,
                color: Colors.white,
                size: 30,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Prop extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  final bool dim;
  const _Prop({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.dim = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkResponse(
      onTap: onTap,
      radius: 52,
      child: Opacity(
        opacity: dim ? .4 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: .92),
                color.withValues(alpha: .88),
              ],
            ),
            border: Border.all(color: Colors.white70, width: 2),
            boxShadow: [BoxShadow(color: color, blurRadius: 18)],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Icon(icon, color: const Color(0xff102638), size: 42),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xff102638),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PowerUnit extends StatelessWidget {
  final bool installed, powered, enabled;
  final VoidCallback onInstall;
  const _PowerUnit({
    required this.installed,
    required this.powered,
    required this.enabled,
    required this.onInstall,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: enabled,
    label: 'Power unit',
    child: InkWell(
      key: const Key('power-unit'),
      onTap: enabled ? onInstall : null,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xdd1d3542),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: powered ? const Color(0xff78d8ce) : const Color(0xff79543f),
            width: 3,
          ),
          boxShadow: powered
              ? const [BoxShadow(color: Color(0xff78d8ce), blurRadius: 24)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              powered
                  ? Icons.bolt_rounded
                  : installed
                  ? Icons.battery_full_rounded
                  : Icons.battery_0_bar_rounded,
              color: powered
                  ? const Color(0xff78d8ce)
                  : const Color(0xffffd494),
              size: 46,
            ),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  powered
                      ? 'ONLINE'
                      : installed
                      ? 'BATTERY READY'
                      : 'POWER UNIT',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ButtonPanel extends StatelessWidget {
  final bool busy;
  final ValueChanged<String> onTap;
  const _ButtonPanel({required this.busy, required this.onTap});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xe6152a39),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xff6c8793), width: 2),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final entry in const [
          ('red', Color(0xffd84e3d)),
          ('green', Color(0xff55c98a)),
          ('yellow', Color(0xffffd05a)),
        ])
          Semantics(
            button: true,
            label: '${entry.$1} button',
            child: InkResponse(
              key: ValueKey('button-${entry.$1}'),
              onTap: busy ? null : () => onTap(entry.$1),
              radius: 34,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.$2,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: entry.$2, blurRadius: 14)],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _RoomBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _RoomBadge({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xc9102638),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xff78d8ce)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xff78d8ce)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FeedbackStrip extends StatelessWidget {
  final LostSignalState state;
  final String? problem;
  const _FeedbackStrip({required this.state, required this.problem});
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 58, maxHeight: 94),
    width: double.infinity,
    color: const Color(0xff102638),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Row(
      children: [
        const Icon(Icons.forum_outlined, color: Color(0xffffd494)),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              problem ??
                  (state.feedback.isEmpty
                      ? 'Explore the station. Your progress saves automatically.'
                      : state.feedback),
              key: const Key('lost-signal-feedback'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        if (state.inventory.isNotEmpty) ...[
          const SizedBox(width: 8),
          for (final item in state.inventory)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Tooltip(
                message: item == 'red_key' ? 'red key' : item,
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: item == 'red_key'
                      ? const Color(0xffd84e3d)
                      : const Color(0xffffd05a),
                  child: Icon(
                    item == 'red_key'
                        ? Icons.key_rounded
                        : Icons.battery_charging_full_rounded,
                    color: const Color(0xff102638),
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ],
    ),
  );
}
