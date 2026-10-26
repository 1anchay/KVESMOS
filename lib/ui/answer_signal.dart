import 'package:flutter/material.dart';
import 'character_moment.dart';
import 'flight_components.dart';

class AnswerSignal extends StatelessWidget {
  final bool correct, animate;
  final int combo;
  const AnswerSignal({
    super.key,
    required this.correct,
    required this.animate,
    required this.combo,
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
        child: Row(
          children: [
            CharacterMoment(
              characterId: 'orbi',
              size: 40,
              animate: animate,
              state: correct ? CharacterState.correct : CharacterState.support,
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
                          : 'В подсказке — следующий шаг.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
