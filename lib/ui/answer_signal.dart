import 'package:flutter/material.dart';
import 'character_moment.dart';
import 'flight_components.dart';

class AnswerSignal extends StatelessWidget {
  final bool correct, animate;
  final int combo;
  final String? explanation, correction;
  const AnswerSignal({
    super.key,
    required this.correct,
    required this.animate,
    required this.combo,
    this.explanation,
    this.correction,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: FlightArrival(
      animate: animate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color:
              (correct
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFAC671C))
                  .withValues(alpha: .10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CharacterMoment(
                  characterId: 'orbi',
                  size: 40,
                  animate: animate,
                  state: correct
                      ? CharacterState.correct
                      : CharacterState.support,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        correct ? 'Есть контакт! +10 XP' : 'Почти! Я помогу.',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (MediaQuery.textScalerOf(context).scale(16) <= 22)
                        Text(
                          correct
                              ? combo >= 3
                                    ? 'Серия: $combo · продолжим!'
                                    : 'Отлично, идём дальше!'
                              : 'Разберём и попробуем ещё раз.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (explanation != null) ...[
              const SizedBox(height: 8),
              Text(explanation!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (correction != null) ...[
              const SizedBox(height: 6),
              Text(correction!, style: Theme.of(context).textTheme.titleSmall),
            ],
          ],
        ),
      ),
    ),
  );
}
