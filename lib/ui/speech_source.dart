import 'package:flutter/material.dart';
import '../services/learning_audio.dart';

class SpeechSourceLabel extends StatelessWidget {
  final LearningAudio audio;
  final String character, text;
  const SpeechSourceLabel({
    super.key,
    required this.audio,
    required this.character,
    required this.text,
  });
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<SpeechPlayback?>(
    valueListenable: audio.playback,
    builder: (context, playback, _) => Text(
      audio.lastCharacter == character &&
              audio.lastText == text &&
              audio.lastProblem != null
          ? audio.lastProblem!
          : audio.lastSource == SpeechSource.recording &&
                audio.lastCharacter == character &&
                audio.lastText == text
          ? 'Локальная запись персонажа'
          : 'Резервная озвучка: системный голос устройства',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}
