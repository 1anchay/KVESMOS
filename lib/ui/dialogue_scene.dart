import 'package:flutter/material.dart';
import 'design.dart';

/// A readable mini-scene with distinct speakers, rather than a text dump.
class DialogueScene extends StatelessWidget {
  final String scene;
  const DialogueScene({super.key, required this.scene});

  @override
  Widget build(BuildContext context) {
    final lines = scene.split('\n').where((line) => line.trim().isNotEmpty);
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
    final text = sep > 0 ? line.substring(sep + 1).trim() : line;
    final id = switch (speaker.toLowerCase()) {
      'мико' => 'miko',
      'орби' => 'orbi',
      'зиг' => 'zig_quartz',
      _ => null,
    };
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (id != null) ...[
          id == 'orbi'
              ? const OrbitRobot(size: 54, emotion: 'happy')
              : CharacterPortrait(id, size: 54),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}
