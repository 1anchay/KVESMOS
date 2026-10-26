import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/learning_audio.dart';

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

/// Finite pose transitions, gestures and Orbi's procedural eyelids. This is not
/// skeletal animation or lip sync: the hand poses come from supplied artwork.
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
  double gaze = 0;
  CharacterState get activeState => interaction ?? widget.effectiveState;
  void play() {
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
        old.animate != widget.animate) {
      interaction = null;
      play();
    }
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
    final pose = switch (state) {
      CharacterState.correct || CharacterState.goodbye => 'wink_thumbsup',
      CharacterState.celebration => 'happy',
      _ => 'thinking',
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
        onTapDown: (details) {
          gaze = ((details.localPosition.dx / widget.size) * 2 - 1).clamp(
            -1.0,
            1.0,
          );
        },
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
              final frames = widget.frames[state];
              final asset = frames != null && frames.isNotEmpty
                  ? frames[(t * frames.length).floor().clamp(
                      0,
                      frames.length - 1,
                    )]
                  : 'assets/kvesmos/${widget.characterId == 'orbi' ? 'orbi_$pose' : widget.characterId}.png';
              final blink = moving
                  ? (1 - ((t - .48) / .05).abs()).clamp(0.0, 1.0)
                  : 0.0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    bottom: 0,
                    width: widget.size,
                    height: widget.size,
                    child: Transform.translate(
                      offset: Offset(
                        profile.sway * wave,
                        -motion.lift * envelope * profile.bounce,
                      ),
                      child: Transform.rotate(
                        angle: motion.tilt * wave * profile.tilt,
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
                            if (widget.characterId == 'orbi' &&
                                pose == 'thinking' &&
                                frames == null)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _OrbiFace(
                                    blink,
                                    moving
                                        ? math.sin(t * math.pi * 2) * .6 +
                                              gaze * envelope
                                        : 0,
                                    state,
                                    moving ? t : 1,
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

class _OrbiFace extends CustomPainter {
  final double amount, gaze, t;
  final CharacterState state;
  _OrbiFace(this.amount, this.gaze, this.state, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    // Coordinates refer only to the supplied 443x406 thinking pose. The other
    // portraits have no isolated eyes; never place these lids on unknown art.
    final scale = math.min(size.width / 443, size.height / 406);
    canvas.translate(
      (size.width - 443 * scale) / 2,
      (size.height - 406 * scale) / 2,
    );
    canvas.scale(scale);
    for (final eye in [const Offset(194, 270), const Offset(315, 219)]) {
      canvas.save();
      canvas.translate(eye.dx, eye.dy);
      canvas.rotate(-.28);
      canvas.drawOval(
        const Rect.fromLTWH(-40, -47, 80, 94),
        Paint()..color = const Color(0xFF010719),
      );
      final open = (1 - amount).clamp(.04, 1.0);
      canvas.save();
      canvas.scale(1, open);
      final happy =
          state == CharacterState.greeting || state == CharacterState.support;
      if (happy) {
        canvas.drawArc(
          const Rect.fromLTWH(-28, -12, 56, 36),
          math.pi + .15,
          math.pi - .3,
          false,
          Paint()
            ..color = const Color(0xFF4AE7FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawOval(
          const Rect.fromLTWH(-31, -40, 62, 80),
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFF78F4FF), Color(0xFF00C7FF)],
            ).createShader(const Rect.fromLTWH(-31, -40, 62, 80)),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(gaze * 10 + 9, -10),
            width: 26,
            height: state == CharacterState.surprise ? 30 : 42,
          ),
          Paint()..color = const Color(0xFF001633),
        );
        canvas.drawCircle(
          Offset(gaze * 10 + 14, -22),
          5,
          Paint()..color = Colors.white.withValues(alpha: .8),
        );
      }
      canvas.restore();
      canvas.restore();
    }
    // The mouth occupies the unobstructed screen area above the original hand.
    canvas.drawOval(
      const Rect.fromLTWH(254, 263, 34, 23),
      Paint()..color = const Color(0xFF010719),
    );
    final mouth = Paint()
      ..color = const Color(0xFF4AE7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    if (state == CharacterState.talking) {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(270, 275),
          width: 14,
          height: 4 + math.sin(t * 36).abs() * 10,
        ),
        mouth,
      );
    } else {
      canvas.drawArc(
        const Rect.fromLTWH(259, 264, 22, 15),
        state == CharacterState.thinking ? math.pi : 0,
        math.pi,
        false,
        mouth,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbiFace old) =>
      amount != old.amount ||
      gaze != old.gaze ||
      state != old.state ||
      t != old.t;
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
