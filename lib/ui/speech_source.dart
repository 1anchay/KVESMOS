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
    builder: (context, playback, _) {
      final same = audio.lastCharacter == character && audio.lastText == text;
      final clip = audio.recordings.find(character, audio.studyLocale, text);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            same && audio.lastProblem != null
                ? audio.lastProblem!
                : same && audio.lastSource == SpeechSource.system
                ? 'Системный голос выбранного языка · текст доступен всегда'
                : clip != null
                ? 'Синтезированная реплика · офлайн'
                : 'Системный голос выбранного языка · текст доступен всегда',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (same && playback != null && (playback.playing || playback.paused))
            Wrap(
              spacing: 8,
              children: [
                if (playback.source == SpeechSource.recording)
                  TextButton.icon(
                    onPressed: audio.pauseOrResume,
                    icon: Icon(
                      playback.paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                    ),
                    label: Text(playback.paused ? 'Продолжить звук' : 'Пауза'),
                  ),
                TextButton.icon(
                  onPressed: audio.stop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Остановить'),
                ),
              ],
            ),
        ],
      );
    },
  );
}
