import 'package:flutter/material.dart';
import 'design.dart';

/// Small finite character reactions for lesson cards.
/// Portraits are still single PNG layers; true lipsync/rigging needs new art.
class CharacterMoment extends StatelessWidget {
  final String characterId;
  final bool? correct;
  final bool talking;
  final double size;

  const CharacterMoment({
    super.key,
    required this.characterId,
    this.correct,
    this.talking = false,
    this.size = 76,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final mood = talking
        ? 'talking'
        : correct == true
        ? 'success'
        : correct == false
        ? 'try-again'
        : 'thinking';
    final symbol = talking
        ? Icons.graphic_eq_rounded
        : correct == true
        ? Icons.auto_awesome_rounded
        : correct == false
        ? Icons.favorite_outline_rounded
        : Icons.star_outline_rounded;
    final accent = correct == true
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.tertiary;

    final portrait = characterId == 'orbi'
        ? OrbitRobot(
            size: size,
            emotion: talking
                ? 'surprised'
                : correct == true
                ? 'wink_thumbsup'
                : correct == false
                ? 'thinking'
                : 'happy',
          )
        : CharacterPortrait(characterId, size: size);

    return SizedBox(
      width: size + 20,
      height: size + 14,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey('pose:$characterId:$mood'),
            tween: Tween(begin: .90, end: 1),
            curve: Curves.easeOutBack,
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 360),
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: AnimatedSwitcher(
              duration: reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              child: KeyedSubtree(
                key: ValueKey('face:$characterId:$mood'),
                child: portrait,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('spark:$characterId:$mood'),
              tween: Tween(begin: 0, end: 1),
              duration: reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 480),
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 7 * (1 - value)),
                  child: child,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 1.5),
                ),
                padding: const EdgeInsets.all(4),
                child: Icon(symbol, color: accent, size: 19),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
