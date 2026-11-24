import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'cutout_actor.dart';
import '../services/learning_audio.dart';

/// The bridge reflects completed learning. It has no separate reward ledger.
class CommandBridge extends StatelessWidget {
  final int completed;
  final bool animate;
  final LearningAudio audio;
  final bool greeting;
  const CommandBridge({
    super.key,
    required this.completed,
    required this.animate,
    required this.audio,
    this.greeting = false,
  });

  Widget _actor(String id, double size, ActorAction action) =>
      ValueListenableBuilder<SpeechPlayback?>(
        valueListenable: audio.playback,
        builder: (_, speech, _) => CutoutActor(
          character: id,
          size: size,
          animate: animate,
          action: speech?.playing == true && speech?.character == id
              ? ActorAction.talking
              : action,
        ),
      );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: SizedBox(
      height: 104,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/kvesmos/scenes/painted_bridge.webp',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            cacheWidth: 1024,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x660A1630),
                  Color(0x000A1630),
                  Color(0xAA0A1630),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 66,
            top: 12,
            child: Text(
              'МОСТИК · ${completed == 0 ? 'ПЕРВЫЙ СИГНАЛ' : 'СВЯЗЬ УСТАНОВЛЕНА'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            right: 22,
            bottom: 0,
            child: _actor(
              'orbi',
              76,
              greeting ? ActorAction.greeting : ActorAction.idle,
            ),
          ),
          Positioned(
            left: 14,
            bottom: 8,
            child: Tooltip(
              message: 'Мико · тренировочная орбита',
              child: Semantics(
                button: true,
                label: 'Мико · открыть практику',
                child: InkWell(
                  onTap: () => context.go('/training'),
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: _actor(
                        'miko',
                        70,
                        completed > 0
                            ? ActorAction.interaction
                            : ActorAction.idle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 5,
            child: IconButton(
              tooltip: 'Открыть карту галактики',
              onPressed: () => context.go('/galaxy'),
              icon: const Icon(Icons.explore_outlined, color: Colors.white),
            ),
          ),
          if (completed >= 4)
            Positioned(
              left: 100,
              bottom: 18,
              child: Tooltip(
                message: 'Завершено не менее четырёх учебных миссий',
                child: Image.asset(
                  'assets/kvesmos/explorer_closed.png',
                  width: 48,
                  height: 44,
                  excludeFromSemantics: true,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
