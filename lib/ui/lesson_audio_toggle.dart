import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import 'design.dart';

/// Effects only. Recorded phrases keep their independent volume and switch.
class LessonAudioToggle extends ConsumerStatefulWidget {
  const LessonAudioToggle({super.key});
  @override
  ConsumerState<LessonAudioToggle> createState() => _LessonAudioToggleState();
}

class _LessonAudioToggleState extends ConsumerState<LessonAudioToggle> {
  bool saving = false;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), prefs = app.audio.preferences;
    return IconButton(
      key: const Key('lesson-effects'),
      tooltip: prefs.effects
          ? 'Выключить звуки ответов'
          : 'Включить звуки ответов',
      isSelected: prefs.effects,
      icon: Icon(
        prefs.effects ? Icons.music_note_rounded : Icons.music_off_rounded,
      ),
      onPressed: saving
          ? null
          : () async {
              setState(() => saving = true);
              try {
                await app.saveAudio(prefs.copyWith(effects: !prefs.effects));
              } catch (_) {
                if (context.mounted) {
                  showMessage(context, 'Не удалось сохранить настройку звука.');
                }
              } finally {
                if (mounted) setState(() => saving = false);
              }
            },
    );
  }
}
