import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/course.dart';
import '../domain/journey.dart';
import 'character_moment.dart';
import 'design.dart';
import 'flight_components.dart';

class MissionCheckpoint extends StatelessWidget {
  final Lesson lesson;
  final int position, xp;
  final bool animate, busy;
  final VoidCallback onContinue;
  const MissionCheckpoint({
    super.key,
    required this.lesson,
    required this.position,
    required this.xp,
    required this.animate,
    required this.busy,
    required this.onContinue,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Сохранить и отдохнуть',
        onPressed: () => context.go('/'),
        icon: const Icon(Icons.close),
      ),
    ),
    body: SafeArea(
      child: pageBody([
        FlightArrival(
          animate: animate,
          child: Column(
            children: [
              CharacterMoment(
                characterId: JourneyRegion.forOrder(lesson.order).guide,
                state: CharacterState.correct,
                size: 112,
                animate: animate,
              ),
              const SizedBox(height: 16),
              Text(
                'Первый этап пройден!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Ты разобрался с основой. Теперь применим её самостоятельно.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FlightPanel(
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$position заданий · $xp XP сохранено',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              FlightProgress(
                value: position,
                target: lesson.exercises.length,
                label: 'Миссия',
              ),
              const SizedBox(height: 14),
              Text(lesson.objective ?? lesson.topic),
              const SizedBox(height: 8),
              Text(
                'До завершения: ${lesson.exercises.length - position} заданий. Награда за урок ждёт в финале.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('checkpoint-continue'),
          onPressed: busy ? null : onContinue,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Второй этап'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Сохранить и отдохнуть'),
        ),
        const Text(
          'Вернёшься к этому месту. Никаких потерянных ответов.',
          textAlign: TextAlign.center,
        ),
      ]),
    ),
  );
}
