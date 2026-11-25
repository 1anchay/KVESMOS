import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  Widget _actor(
    String id,
    double size,
  ) => ValueListenableBuilder<SpeechPlayback?>(
    valueListenable: audio.playback,
    builder: (context, speech, _) {
      final speaking = speech?.playing == true && speech?.character == id;
      final asset = id == 'miko'
          ? 'crew_motion/miko_bridge.webp'
          : (greeting && animate ? 'orbi_wink_thumbsup.png' : 'orbi_happy.png');
      final motion = animate && !MediaQuery.disableAnimationsOf(context);
      return AnimatedSlide(
        duration: motion ? const Duration(milliseconds: 180) : Duration.zero,
        offset: motion && speaking ? const Offset(0, -.025) : Offset.zero,
        child: Image.asset(
          'assets/kvesmos/$asset',
          width: size,
          height: size * 1.18,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          semanticLabel: id == 'miko' ? 'Навигатор Мико' : 'Орби приветствует',
        ),
      );
    },
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
            left: 100,
            right: 100,
            top: 12,
            child: Text(
              'МОСТИК',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(right: 22, bottom: 0, child: _actor('orbi', 76)),
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
                    child: IgnorePointer(child: _actor('miko', 82)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 98,
            right: 98,
            bottom: 10,
            child: Tooltip(
              message: 'Открыть карту галактики',
              child: MediaQuery.textScalerOf(context).scale(14) > 20
                  ? IconButton(
                      onPressed: () => context.go('/galaxy'),
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x990A1630),
                      ),
                      icon: const Icon(Icons.explore_outlined),
                    )
                  : TextButton.icon(
                      onPressed: () => context.go('/galaxy'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0x990A1630),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.explore_outlined, size: 18),
                      label: const Text('Карта'),
                    ),
            ),
          ),
          if (completed >= 4)
            Positioned(
              left: 83,
              bottom: 0,
              child: Tooltip(
                message: 'Завершено не менее четырёх учебных миссий',
                child: Image.asset(
                  'assets/kvesmos/explorer_closed.png',
                  width: 25,
                  height: 23,
                  excludeFromSemantics: true,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
