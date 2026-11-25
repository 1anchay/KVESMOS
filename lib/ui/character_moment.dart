import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/learning_audio.dart';
import 'character_animation_catalog.dart';

/// States are independent of the renderer: licensed frame sets can replace the
/// current pose/gesture renderer without changing lesson or playback logic.
enum CharacterState {
  idle,
  greeting,
  talking,
  listening,
  thinking,
  correct,
  support,
  celebration,
  surprise,
  goodbye,
}

class SpeakingCharacter extends StatelessWidget {
  final LearningAudio audio;
  final String character;
  final CharacterState state;
  final double size;
  const SpeakingCharacter({
    super.key,
    required this.audio,
    required this.character,
    this.state = CharacterState.idle,
    this.size = 76,
  });
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<SpeechPlayback?>(
    valueListenable: audio.playback,
    builder: (context, playback, _) => CharacterMoment(
      characterId: character,
      size: size,
      animate: audio.preferences.reactions,
      state: playback?.playing == true && playback?.character == character
          ? CharacterState.talking
          : state,
    ),
  );
}

class CharacterMotion {
  final double tilt, lift;
  final int milliseconds, beats;
  const CharacterMotion(this.tilt, this.lift, this.milliseconds, this.beats);
  static CharacterMotion forState(CharacterState state) => switch (state) {
    CharacterState.idle => const CharacterMotion(.025, 3, 1800, 1),
    CharacterState.greeting => const CharacterMotion(.14, 10, 1100, 2),
    CharacterState.talking => const CharacterMotion(.05, 4, 1800, 4),
    CharacterState.listening => const CharacterMotion(-.10, 2, 1200, 1),
    CharacterState.thinking => const CharacterMotion(-.13, 3, 1500, 1),
    CharacterState.correct => const CharacterMotion(.10, 15, 950, 2),
    CharacterState.support => const CharacterMotion(.07, 4, 1400, 2),
    CharacterState.celebration => const CharacterMotion(.20, 20, 1800, 3),
    CharacterState.surprise => const CharacterMotion(-.09, 12, 900, 1),
    CharacterState.goodbye => const CharacterMotion(.17, 5, 1300, 3),
  };
}

/// Individual timing and gesture amplitude, shared by all ten state triggers.
class CharacterAnimationProfile {
  final double tempo, tilt, bounce, sway;
  const CharacterAnimationProfile(
    this.tempo,
    this.tilt,
    this.bounce,
    this.sway,
  );
  static CharacterAnimationProfile forId(String id) => switch (id) {
    'miko' => const CharacterAnimationProfile(1.25, .7, .65, -5),
    'zig_quartz' => const CharacterAnimationProfile(.8, 1.3, 1.4, 9),
    'orbi' => const CharacterAnimationProfile(1.1, .55, .7, 2),
    'nox' => const CharacterAnimationProfile(1.4, .4, .4, -2),
    _ => const CharacterAnimationProfile(1, .8, .8, 3),
  };
}

/// Event-driven pose transitions using the supplied character illustrations.
class CharacterMoment extends StatefulWidget {
  final String characterId;
  final bool? correct;
  final bool talking;
  final double size;
  final CharacterState? state;
  final bool animate;
  final Map<CharacterState, List<String>> frames;
  const CharacterMoment({
    super.key,
    required this.characterId,
    this.correct,
    this.talking = false,
    this.size = 76,
    this.state,
    this.animate = true,
    this.frames = const {},
  });
  CharacterState get effectiveState =>
      state ??
      (talking
          ? CharacterState.talking
          : correct == true
          ? CharacterState.correct
          : correct == false
          ? CharacterState.support
          : CharacterState.idle);
  @override
  State<CharacterMoment> createState() => _CharacterMomentState();
}

class _CharacterMomentState extends State<CharacterMoment>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(vsync: this);
  bool reduce = false;
  CharacterState? interaction;
  CharacterState get activeState => interaction ?? widget.effectiveState;
  List<String> _castFrames = const [];
  void play() {
    if (CharacterAnimationCatalog.cast.contains(widget.characterId)) {
      _castFrames =
          widget.frames[activeState] ??
          CharacterAnimationCatalog.frames(
            widget.characterId,
            activeState.name,
          );
      for (final asset in _castFrames) {
        precacheImage(
          AssetImage(asset),
          context,
          onError: (error, _) {
            debugPrint('Missing crew pose: $asset');
          },
        );
      }
    } else {
      _castFrames = const [];
    }
    controller.duration = Duration(
      milliseconds:
          (CharacterMotion.forState(activeState).milliseconds *
                  CharacterAnimationProfile.forId(widget.characterId).tempo)
              .round(),
    );
    if (reduce || !widget.animate || activeState == CharacterState.idle) {
      controller.stop();
      controller.value = 1;
    } else {
      controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduce = MediaQuery.disableAnimationsOf(context);
    play();
  }

  @override
  void didUpdateWidget(CharacterMoment old) {
    super.didUpdateWidget(old);
    if (old.effectiveState != widget.effectiveState ||
        old.characterId != widget.characterId ||
        old.frames != widget.frames ||
        old.animate != widget.animate) {
      interaction = null;
      play();
    }
  }

  void _react() {
    setState(
      () => interaction = switch (interaction) {
        CharacterState.greeting => CharacterState.thinking,
        CharacterState.thinking => CharacterState.celebration,
        CharacterState.celebration => CharacterState.support,
        CharacterState.support => CharacterState.surprise,
        _ => CharacterState.greeting,
      },
    );
    play();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = activeState;
    final motion = CharacterMotion.forState(state);
    final profile = CharacterAnimationProfile.forId(widget.characterId);
    final name = CharacterVoiceProfile.forId(widget.characterId).name;
    final label = switch (state) {
      CharacterState.idle => 'рядом',
      CharacterState.greeting => 'приветствует',
      CharacterState.talking => 'говорит',
      CharacterState.listening => 'слушает',
      CharacterState.thinking => 'размышляет',
      CharacterState.correct => 'радуется ответу',
      CharacterState.support => 'поддерживает',
      CharacterState.celebration => 'празднует',
      CharacterState.surprise => 'удивляется',
      CharacterState.goodbye => 'прощается',
    };
    if (_castFrames.isNotEmpty) {
      return Semantics(
        label: '$name $label',
        image: true,
        button: true,
        onTap: _react,
        child: GestureDetector(
          excludeFromSemantics: true,
          onTap: _react,
          child: SizedBox(
            width: widget.size + 20,
            height: widget.size + 22,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final t = controller.value;
                final index = _castFrames.length == 1
                    ? 0
                    : t < .28
                    ? 0
                    : _castFrames.length - 1;
                return AnimatedSwitcher(
                  duration: reduce || !widget.animate
                      ? Duration.zero
                      : const Duration(milliseconds: 135),
                  child: Image.asset(
                    _castFrames[index],
                    key: ValueKey(_castFrames[index]),
                    fit: BoxFit.contain,
                    width: widget.size + 12,
                    height: widget.size + 12,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => Image.asset(
                      CharacterAnimationCatalog.neutral(widget.characterId),
                      width: widget.size,
                      height: widget.size,
                      excludeFromSemantics: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
    final pose = switch (state) {
      CharacterState.correct || CharacterState.goodbye => 'wink_thumbsup',
      CharacterState.celebration => 'happy',
      CharacterState.thinking ||
      CharacterState.listening ||
      CharacterState.support => 'thinking',
      CharacterState.surprise => 'surprised',
      _ => 'happy',
    };
    final symbol = switch (state) {
      CharacterState.correct ||
      CharacterState.celebration => Icons.auto_awesome_rounded,
      CharacterState.support => Icons.favorite_outline_rounded,
      CharacterState.talking => Icons.graphic_eq_rounded,
      CharacterState.listening => Icons.hearing_rounded,
      CharacterState.greeting ||
      CharacterState.goodbye => Icons.waving_hand_rounded,
      CharacterState.surprise => Icons.priority_high_rounded,
      CharacterState.thinking => Icons.psychology_alt_rounded,
      _ => Icons.star_outline_rounded,
    };
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: '$name $label',
      image: true,
      button: true,
      hint: 'Коснись, чтобы поздороваться',
      child: GestureDetector(
        onTap: () {
          setState(
            () => interaction = interaction == CharacterState.greeting
                ? CharacterState.surprise
                : CharacterState.greeting,
          );
          play();
        },
        child: SizedBox(
          width: widget.size + 20,
          height: widget.size + 22,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final t = controller.value;
              final moving =
                  !reduce && widget.animate && state != CharacterState.idle;
              final envelope = moving ? math.sin(math.pi * t) : 0.0;
              final wave = math.sin(t * math.pi * motion.beats * 2) * envelope;
              // Three different gesture paths, not one bounce at different speeds.
              // These transform supplied portraits; they are not skeletal rigs.
              final (
                gestureX,
                gestureY,
                gestureAngle,
              ) = switch (widget.characterId) {
                'miko' => (
                  8 * envelope * (1 - 2 * t),
                  -2 * envelope,
                  -.055 * envelope,
                ),
                'zig_quartz' => (
                  6 * envelope * math.sin(t * math.pi * 4),
                  -3 * envelope,
                  -.09 * envelope * math.sin(t * math.pi * 2),
                ),
                _ => (
                  profile.sway * wave,
                  -motion.lift * envelope * profile.bounce,
                  motion.tilt * wave * profile.tilt,
                ),
              };
              final frames = widget.frames[state];
              final asset = frames != null && frames.isNotEmpty
                  ? frames[(t * frames.length).floor().clamp(
                      0,
                      frames.length - 1,
                    )]
                  : 'assets/kvesmos/${widget.characterId == 'orbi' ? 'orbi_$pose' : widget.characterId}.png';
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    bottom: 0,
                    width: widget.size,
                    height: widget.size,
                    child: Transform.translate(
                      offset: Offset(gestureX, gestureY),
                      child: Transform.rotate(
                        angle: gestureAngle,
                        alignment: Alignment.bottomCenter,
                        child: Stack(
                          children: [
                            AnimatedSwitcher(
                              duration: reduce
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                              child: ClipRRect(
                                key: ValueKey(asset),
                                borderRadius: BorderRadius.circular(22),
                                child: Image.asset(
                                  asset,
                                  width: widget.size,
                                  height: widget.size,
                                  fit: BoxFit.contain,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (state == CharacterState.celebration ||
                      state == CharacterState.correct)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CelebrationParticles(t, moving, accent),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: accent),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(symbol, size: 19, color: accent),
                      ),
                    ),
                  ),
                  if (state == CharacterState.talking)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(
                          4,
                          (i) => Container(
                            width: 3,
                            height:
                                5 +
                                (moving
                                    ? (math.sin(t * 24 + i).abs() *
                                          10 *
                                          envelope)
                                    : 4),
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CelebrationParticles extends CustomPainter {
  final double t;
  final bool animate;
  final Color color;
  _CelebrationParticles(this.t, this.animate, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (!animate || t == 1) return;
    final paint = Paint()..color = color.withValues(alpha: 1 - t);
    for (var i = 0; i < 9; i++) {
      final angle = i * math.pi * 2 / 9;
      final radius = size.width * (.2 + .4 * t);
      canvas.drawCircle(
        Offset(
          size.width / 2 + math.cos(angle) * radius,
          size.height / 2 + math.sin(angle) * radius,
        ),
        2 + (i % 3).toDouble(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CelebrationParticles old) =>
      old.t != t || old.animate != animate || old.color != color;
}
