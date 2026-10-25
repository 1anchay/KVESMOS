import 'package:flutter/material.dart';
import '../domain/course.dart';
import 'character_moment.dart';
import '../services/learning_audio.dart';
import 'speech_source.dart';
import 'galaxy_components.dart';

/// A short teaching sequence, shown before the first exercise of a lesson.
class LessonIntroduction extends StatefulWidget {
  final Lesson lesson;
  final Future<void> Function() onStart;
  final Future<void> Function(int)? onStep;
  final VoidCallback? onClose;
  final int initialStep;
  final LearningAudio audio;

  const LessonIntroduction({
    super.key,
    required this.lesson,
    required this.onStart,
    required this.audio,
    this.onStep,
    this.onClose,
    this.initialStep = 0,
  });

  @override
  State<LessonIntroduction> createState() => _LessonIntroductionState();
}

class _LessonIntroductionState extends State<LessonIntroduction> {
  late int index = widget.initialStep.clamp(
    0,
    widget.lesson.teachingSteps.length - 1,
  );
  final scroll = ScrollController();
  bool busy = false;
  bool talking = false;

  Future<void> listen({bool slow = false}) async {
    if (talking) return;
    setState(() => talking = true);
    final step = widget.lesson.teachingSteps[index];
    final ok = await widget.audio.speak(
      step.phrase,
      character: step.character,
      slow: slow,
    );
    if (!mounted) return;
    setState(() => talking = false);
    if (!ok && widget.audio.lastProblem != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.audio.lastProblem!)));
    }
  }

  Future<void> advance(int next) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.audio.stop();
      if (next == widget.lesson.teachingSteps.length) {
        await widget.onStart();
      } else {
        await widget.onStep?.call(next);
        if (!mounted) return;
        setState(() {
          index = next;
          talking = false;
        });
        if (scroll.hasClients) scroll.jumpTo(0);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить шаг. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.lesson.teachingSteps[index];
    final theme = Theme.of(context);
    final last = index == widget.lesson.teachingSteps.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сначала разберёмся'),
        leading: widget.onClose == null
            ? null
            : IconButton(
                tooltip: 'Закрыть и сохранить',
                onPressed: busy
                    ? null
                    : () async {
                        await widget.audio.stop();
                        if (mounted) widget.onClose!();
                      },
                icon: const Icon(Icons.close),
              ),
      ),
      body: SafeArea(
        child: GalaxyField(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.all(20),
                      children: [
                        LinearProgressIndicator(
                          value:
                              (index + 1) / widget.lesson.teachingSteps.length,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 16),
                        if (index == 0 && widget.lesson.objective != null) ...[
                          Text(
                            'Твоя миссия: ${widget.lesson.objective}',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'Шаг ${index + 1} из ${widget.lesson.teachingSteps.length}',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: SpeakingCharacter(
                            key: ValueKey(index),
                            audio: widget.audio,
                            character: step.character,
                            state: index == 0
                                ? CharacterState.greeting
                                : last && widget.lesson.id == 'a1-01'
                                ? CharacterState.goodbye
                                : CharacterState.thinking,
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
                                Text(
                                  step.phrase,
                                  style: theme.textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  step.translation,
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: talking || busy
                                          ? null
                                          : listen,
                                      icon: const Icon(Icons.volume_up_rounded),
                                      label: const Text('Послушать пример'),
                                    ),
                                    TextButton.icon(
                                      onPressed: talking || busy
                                          ? null
                                          : () => listen(slow: true),
                                      icon: const Icon(Icons.slow_motion_video),
                                      label: const Text('Медленнее'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 30),
                                SpeechSourceLabel(
                                  audio: widget.audio,
                                  character: step.character,
                                  text: step.phrase,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  step.explanation,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Сначала прочитай и пойми пример. В заданиях мы потренируем его без спешки.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        if (index > 0)
                          IconButton(
                            key: const Key('teaching-back'),
                            tooltip: 'Назад к объяснению',
                            onPressed: busy ? null : () => advance(index - 1),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        Expanded(
                          child: FilledButton(
                            key: const Key('teaching-next'),
                            onPressed: busy ? null : () => advance(index + 1),
                            child: Text(
                              busy
                                  ? 'Сохраняем…'
                                  : last
                                  ? 'Начать практику'
                                  : 'Понятно, дальше',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
