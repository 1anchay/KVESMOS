import 'package:flutter/material.dart';
import '../domain/course.dart';
import '../services/learning_audio.dart';
import 'character_moment.dart';
import 'flight_components.dart';
import 'design.dart';

class StoryResponse extends StatelessWidget {
  final Exercise exercise;
  final bool correct, neededHelp;
  final LearningAudio audio;
  const StoryResponse({
    super.key,
    required this.exercise,
    required this.correct,
    required this.neededHelp,
    required this.audio,
  });
  @override
  Widget build(BuildContext context) {
    final story = exercise.story!;
    final line = !correct
        ? story.support
        : neededHelp
        ? story.recovered
        : story.success;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: FlightArrival(
        animate: audio.preferences.reactions,
        child: FlightPanel(
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SpeakingCharacter(
                    audio: audio,
                    character: exercise.character,
                    size: 52,
                    state: correct
                        ? CharacterState.correct
                        : CharacterState.support,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      line,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              Text(
                !correct
                    ? 'Герой предлагает помощь: прочитай объяснение и попробуй снова.'
                    : neededHelp
                    ? 'Команда заметила, как ты справился после подсказки.'
                    : 'Твой ответ продвинул историю.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final slow in [false, true])
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await audio.speak(
                          line,
                          character: exercise.character,
                          slow: slow,
                        );
                        if (!ok && context.mounted) {
                          showMessage(
                            context,
                            audio.lastProblem ?? 'Реплика доступна в тексте.',
                          );
                        }
                      },
                      icon: Icon(
                        slow
                            ? Icons.slow_motion_video
                            : Icons.volume_up_outlined,
                        size: 18,
                      ),
                      label: Text(slow ? 'Медленно' : 'Реплика героя'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
