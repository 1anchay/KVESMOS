import 'package:flutter/material.dart';
import '../services/learning_audio.dart';
import 'character_moment.dart';

/// A readable mini-scene with distinct speakers, rather than a text dump.
class DialogueScene extends StatelessWidget {
  final String scene;
  final LearningAudio? audio;
  final String? reply;
  const DialogueScene({super.key, required this.scene, this.audio, this.reply});

  @override
  Widget build(BuildContext context) {
    final lines = scene
        .split('\n')
        .where(
          (line) =>
              line.trim().isNotEmpty &&
              (!line.trim().startsWith('Ты:') || reply != null),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _dialogueLine(context, line),
          ),
      ],
    );
  }

  Widget _dialogueLine(BuildContext context, String line) {
    final sep = line.indexOf(':');
    final speaker = sep > 0 ? line.substring(0, sep).trim() : '';
    final original = sep > 0 ? line.substring(sep + 1).trim() : line;
    final text = speaker == 'Ты' && reply != null ? reply! : original;
    final id = switch (speaker.toLowerCase()) {
      'мико' => 'miko',
      'орби' => 'orbi',
      'зиг' => 'zig_quartz',
      'зиг кварц' => 'zig_quartz',
      'рэйво' => 'reyvo',
      'астэр' => 'aster',
      'веспа' => 'vespa',
      'пикси' => 'pixie',
      'нокс' => 'nox',
      'профессор' || 'профессор-лис' => 'fox_scholar',
      _ => null,
    };
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (id != null) ...[
          if (audio != null)
            SpeakingCharacter(
              audio: audio!,
              character: id,
              size: 48,
              state: reply == null
                  ? CharacterState.listening
                  : CharacterState.correct,
            )
          else
            CharacterMoment(
              characterId: id,
              size: 48,
              state: CharacterState.listening,
            ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (speaker.isNotEmpty)
                  Text(speaker, style: theme.textTheme.labelLarge),
                Text(text, style: theme.textTheme.bodyLarge),
                if (audio != null && id != null && text != '…' && text != '...')
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await audio!.speak(
                        text,
                        character: id,
                        locale: RegExp('[А-Яа-яЁё]').hasMatch(text)
                            ? 'ru-RU'
                            : 'en-US',
                      );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              audio!.lastProblem ??
                                  'Прочитай реплику и продолжи разговор.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.volume_up_outlined, size: 18),
                    label: Text('Послушать: $speaker'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
