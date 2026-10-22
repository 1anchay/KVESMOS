import 'package:flutter/material.dart';
import '../domain/course.dart';
import 'design.dart';
import 'character_moment.dart';
import '../services/learning_audio.dart';

/// A short teaching sequence, shown before the first exercise of a lesson.
class LessonIntroduction extends StatefulWidget {
  final Lesson lesson;
  final VoidCallback onStart;
  final LearningAudio audio;

  const LessonIntroduction({
    super.key,
    required this.lesson,
    required this.onStart,
    required this.audio,
  });

  @override
  State<LessonIntroduction> createState() => _LessonIntroductionState();
}

class _LessonIntroductionState extends State<LessonIntroduction> {
  int index = 0;
  bool talking = false;

  Future<void> listen() async {
    if (talking) return;
    setState(() => talking = true);
    final step = widget.lesson.teachingSteps[index];
    await widget.audio.speak(step.phrase, character: step.character);
    if (mounted) setState(() => talking = false);
  }

  @override
  void dispose() {
    // The lesson screen owns the audio service; do not dispose of it here.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.lesson.teachingSteps[index];
    final theme = Theme.of(context);
    final last = index == widget.lesson.teachingSteps.length - 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Сначала разберёмся')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                LinearProgressIndicator(
                  value: (index + 1) / widget.lesson.teachingSteps.length,
                  minHeight: 8,
                ),
                const SizedBox(height: 16),
                Text(
                  'Знакомство с английским · ${index + 1} из ${widget.lesson.teachingSteps.length}',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 24),
                Center(
                  child: CharacterMoment(
                    characterId: step.character,
                    talking: talking,
                    size: 120,
                  ),
                ),
                const SizedBox(height: 20),
                Text(step.title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.phrase, style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(step.translation, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: talking ? null : listen,
                          icon: const Icon(Icons.volume_up_rounded),
                          label: const Text('Послушать пример'),
                        ),
                        const Divider(height: 30),
                        Text(step.explanation, style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Сначала прочитай и пойми пример. В заданиях мы потренируем его без спешки.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: last
                      ? widget.onStart
                      : () {
                          widget.audio.stop();
                          setState(() {
                            index++;
                            talking = false;
                          });
                        },
                  child: Text(last ? 'Начать практику' : 'Понятно, дальше'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
