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
  final drafts = <String, double>{};
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

  Widget channel(
    String title,
    String volumeLabel,
    bool enabled,
    double volume,
    Future<void> Function(bool) toggle,
    Future<void> Function(double) setVolume,
  ) {
    final percent = '${((drafts[title] ?? volume) * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          value: enabled,
          onChanged: busy ? null : (value) => act(() => toggle(value)),
        ),
        Text('$volumeLabel · $percent'),
        Slider(
          value: drafts[title] ?? volume,
          divisions: 20,
          label: percent,
          semanticFormatterCallback: (value) =>
              '$volumeLabel ${(value * 100).round()}%',
          onChanged: busy
              ? null
              : (value) => setState(() => drafts[title] = value),
          onChangeEnd: (value) => act(() async {
            try {
              await setVolume(value);
            } finally {
              drafts.remove(title);
            }
          }),
        ),
      ],
    );
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
          title: const Text('Без звука'),
          subtitle: const Text('Временно отключает все каналы'),
          value: p.muted,
          onChanged: busy
              ? null
              : (value) => act(() => app.saveAudio(p.copyWith(muted: value))),
        ),
        channel(
          'Музыка',
          'Громкость музыки',
          p.music,
          p.musicVolume,
          (v) => app.saveAudio(p.copyWith(music: v)),
          (v) => app.saveAudio(p.copyWith(musicVolume: v)),
        ),
        channel(
          'Звуки окружения',
          'Громкость окружения',
          p.ambience,
          p.ambienceVolume,
          (v) => app.saveAudio(p.copyWith(ambience: v)),
          (v) => app.saveAudio(p.copyWith(ambienceVolume: v)),
        ),
        channel(
          'Озвучка',
          'Громкость речи',
          p.speech,
          p.speechVolume,
          (v) => app.saveAudio(p.copyWith(speech: v)),
          (v) => app.saveAudio(p.copyWith(speechVolume: v)),
        ),
        channel(
          'Звуковые эффекты',
          'Громкость эффектов',
          p.effects,
          p.effectsVolume,
          (v) => app.saveAudio(p.copyWith(effects: v)),
          (v) => app.saveAudio(p.copyWith(effectsVolume: v)),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: busy
                ? null
                : () => act(() => app.saveAudio(const AudioPreferences())),
            child: const Text('Сбросить настройки звука'),
          ),
        ),
        Text(
          audio.recordings.recordings.isEmpty
              ? 'Студийные записи персонажей пока не добавлены. Доступна резервная озвучка голосами устройства.'
              : 'Офлайн: ${audio.recordings.recordings.length} реплик на разных языках, ${audio.recordings.recordings.map((r) => r.performer).toSet().length} синтезированных голоса. Обычные и медленные версии. Это синтез, не запись актёров. Для остальных фраз — системный голос.',
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
              child: const Text('Остановить речь и эффекты'),
            ),
          ],
        ),
        if (message != null) Text(message!),
        if (audio.voices.scanned) ...[
          Text(
            'Разных голосов устройства: ${audio.voices.distinctVoiceCount(locale)}. Персонажи могут использовать один и тот же голос.',
          ),
          const Text(
            'Голоса с обязательным интернетом исключены. Установите офлайн-пакет изучаемого языка и русский в системных настройках TTS. Уникальность и пол голоса зависят от движка; параметры не имитируют актёров.',
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in {
                'en-US': 'English',
                'es-ES': 'Español',
                'de-DE': 'Deutsch',
                'fr-FR': 'Français',
                'zh-CN': '普通话 · путунхуа',
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
                                {
                                  'en-US': 'Hello! Let us learn together.',
                                  'es-ES': '¡Hola! Vamos a aprender juntos.',
                                  'de-DE': 'Hallo! Lernen wir zusammen.',
                                  'fr-FR': 'Bonjour ! Apprenons ensemble.',
                                  'zh-CN': '你好！我们一起学习。',
                                  'ru-RU': 'Привет! Давай учиться вместе.',
                                }[locale]!,
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
