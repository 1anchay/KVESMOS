import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../services/learning_audio.dart';
import 'design.dart';

class AudioSettings extends ConsumerStatefulWidget {
  const AudioSettings({super.key});
  @override
  ConsumerState<AudioSettings> createState() => _AudioSettingsState();
}

class _AudioSettingsState extends ConsumerState<AudioSettings> {
  bool busy = false;
  String locale = 'en-US';
  String? message;
  double? speechDraft, effectsDraft;
  Future<void> act(Future<void> Function() work) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await work();
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Не удалось сохранить настройки. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), audio = app.audio;
    final p = audio.preferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Звук и голоса'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Озвучка'),
          subtitle: const Text('Учебные фразы и реплики по нажатию'),
          value: p.speech,
          onChanged: busy
              ? null
              : (v) => act(() => app.saveAudio(p.copyWith(speech: v))),
        ),
        Text(
          'Громкость речи · ${((speechDraft ?? p.speechVolume) * 100).round()}%',
        ),
        Slider(
          value: speechDraft ?? p.speechVolume,
          divisions: 10,
          label: '${(p.speechVolume * 100).round()}%',
          onChanged: busy ? null : (v) => setState(() => speechDraft = v),
          onChangeEnd: (v) => act(() async {
            await app.saveAudio(p.copyWith(speechVolume: v));
            speechDraft = null;
          }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Звуковые эффекты'),
          value: p.effects,
          onChanged: busy
              ? null
              : (v) => act(() => app.saveAudio(p.copyWith(effects: v))),
        ),
        Text(
          'Громкость эффектов · ${((effectsDraft ?? p.effectsVolume) * 100).round()}%',
        ),
        Slider(
          value: effectsDraft ?? p.effectsVolume,
          divisions: 10,
          label: '${(p.effectsVolume * 100).round()}%',
          onChanged: busy ? null : (v) => setState(() => effectsDraft = v),
          onChangeEnd: (v) => act(() async {
            await app.saveAudio(p.copyWith(effectsVolume: v));
            effectsDraft = null;
          }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Реакции команды в уроках'),
          subtitle: const Text(
            'Короткие подсказки и поздравления. Озвучка только по нажатию.',
          ),
          value: p.reactions,
          onChanged: busy
              ? null
              : (v) => act(() => app.saveAudio(p.copyWith(reactions: v))),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => act(() async {
                      await audio.voices.refresh();
                    }),
              icon: const Icon(Icons.record_voice_over),
              label: Text(busy ? 'Проверяем…' : 'Проверить голоса устройства'),
            ),
            TextButton(
              onPressed: () async {
                await audio.play(SoundEffect.correct);
              },
              child: const Text('Проверить эффект'),
            ),
            TextButton(
              onPressed: audio.stop,
              child: const Text('Остановить звук'),
            ),
          ],
        ),
        if (message != null) Text(message!),
        if (audio.voices.scanned) ...[
          const Text(
            'Голоса с обязательным интернетом исключены. Установите английский и русский офлайн-пакеты в системных настройках TTS. Уникальность и пол голоса зависят от движка; параметры не имитируют актёров.',
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in {
                'en-US': 'English',
                'ru-RU': 'Русский',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: locale == entry.key,
                  onSelected: (_) => setState(() => locale = entry.key),
                ),
            ],
          ),
          for (final profile in CharacterVoiceProfile.all)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _voiceDescription(
                        audio.voices.voiceFor(profile.id, locale),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final slow in [false, true])
                          TextButton.icon(
                            onPressed: () async {
                              final ok = await audio.speak(
                                locale == 'en-US'
                                    ? 'Hello! Let us learn together.'
                                    : 'Привет! Давай учиться вместе.',
                                character: profile.id,
                                locale: locale,
                                slow: slow,
                              );
                              if (!ok && context.mounted) {
                                showMessage(
                                  context,
                                  'Звук выключен, недоступен или прерван. Текстовый режим работает.',
                                );
                              }
                            },
                            icon: Icon(
                              slow ? Icons.slow_motion_video : Icons.volume_up,
                            ),
                            label: Text(slow ? 'Медленно' : 'Послушать'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  String _voiceDescription(DeviceVoice? v) => v == null
      ? 'Нет подходящего голоса — доступен текст.'
      : '${v.name} · ${v.locale}\n${v.networkRequired == false ? 'Голос устройства, без обязательной сети' : 'Офлайн-доступность движком не подтверждена'}';
}
