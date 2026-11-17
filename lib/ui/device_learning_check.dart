import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/controller.dart';
import '../domain/languages.dart';
import '../services/device.dart';
import '../services/learning_audio.dart';
import 'design.dart';

class DeviceLearningCheck extends ConsumerStatefulWidget {
  const DeviceLearningCheck({super.key});

  @override
  ConsumerState<DeviceLearningCheck> createState() =>
      _DeviceLearningCheckState();
}

class _DeviceLearningCheckState extends ConsumerState<DeviceLearningCheck> {
  final voice = VoiceService();
  late final app = ref.read(appProvider);
  late StudyCourse course = app.course;
  Map<String, dynamic> capabilities = {}, media = {};
  bool busy = false, consent = false;
  String audioStatus = '', transcript = '';

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final permitted =
        await app.repository.setting(VoiceService.networkSetting) == 'true';
    var device = <String, dynamic>{}, volume = <String, dynamic>{};
    try {
      device = await VoiceService.capabilities();
      volume =
          await SoundEffectsService.channel.invokeMapMethod<String, dynamic>(
            'audioStatus',
          ) ??
          {};
    } catch (_) {
      // The Android information is optional on other platforms.
    }
    await app.audio.voices.refresh();
    if (mounted) {
      setState(() {
        consent = permitted;
        capabilities = device;
        media = volume;
      });
    }
  }

  Future<void> play(String phrase, String character, bool slow) async {
    setState(() {
      busy = true;
      audioStatus = 'Запускаю воспроизведение…';
    });
    await voice.stop();
    final ok = await app.audio.speak(
      phrase,
      character: character,
      locale: course.locale,
      slow: slow,
    );
    final text = ok
        ? (app.audio.lastSource == SpeechSource.recording
              ? 'Запись в приложении запущена'
              : 'Голос Android запущен')
        : app.audio.lastProblem ?? 'Не удалось начать воспроизведение.';
    await refresh();
    if (mounted) {
      setState(() {
        busy = false;
        audioStatus = text;
      });
    }
  }

  Future<void> record({bool network = false}) async {
    if (voice.active) {
      await voice.stop(keepResult: true);
      return;
    }
    setState(() => transcript = '');
    await app.audio.stop();
    if (!mounted) return;
    await voice.listen(
      (text) {
        if (mounted) setState(() => transcript = text);
      },
      (_) {},
      language: course.language,
      allowNetwork: network,
      testNetwork: network,
      onDone: () {
        if (mounted) unawaited(refresh());
      },
    );
  }

  Future<void> setConsent(bool enabled) async {
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Разрешить системное распознавание?'),
          content: const Text(
            'Если локальное распознавание недоступно, системная служба Android может передавать речь по сети. KVESMOS не сохраняет аудио. Разрешение можно отозвать здесь в любой момент.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Разрешить'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await voice.stop();
    await app.repository.setSetting(VoiceService.networkSetting, '$enabled');
    if (mounted) setState(() => consent = enabled);
  }

  @override
  void dispose() {
    unawaited(voice.stop());
    unawaited(app.audio.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = app.audio;
    final entries = audio.recordings.recordings.where(
      (clip) => clip.locale == course.locale,
    );
    final sample = entries.firstOrNull;
    final systemVoice = audio.voices.voiceFor('orbi', course.locale);
    final phrase = sample?.text ?? '你好！';
    final permission = switch (capabilities['permission']) {
      'granted' => 'разрешён',
      'denied' => 'ещё не разрешён',
      'blocked' => 'заблокирован в настройках Android',
      _ => 'статус недоступен',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Проверить звук и микрофон')),
      body: pageBody([
        Wrap(
          spacing: 8,
          children: [
            for (final item in StudyCourse.all)
              ChoiceChip(
                label: Text(item.name),
                selected: course.id == item.id,
                onSelected: busy || voice.active
                    ? null
                    : (_) {
                        unawaited(audio.stop());
                        setState(() {
                          course = item;
                          audioStatus = '';
                          transcript = '';
                        });
                      },
              ),
          ],
        ),
        SectionTitle('Озвучка · ${course.locale}'),
        Text('Реплик в приложении: ${entries.length}'),
        Text(
          systemVoice == null
              ? 'Офлайн-голос Android: не найден'
              : 'Голос Android: ${systemVoice.name} · ${systemVoice.locale}',
        ),
        if (media['volume'] != null)
          Text(
            'Медиа Android: ${media['volume']} / ${media['maximum']}${media['muted'] == true ? ' · без звука' : ''}',
          ),
        Text(phrase, style: Theme.of(context).textTheme.titleLarge),
        if (course.language == 'zh') const Text('Nǐ hǎo!'),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: busy
                  ? null
                  : () => play(phrase, sample?.character ?? 'orbi', false),
              child: const Text('Послушать'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => play(phrase, sample?.character ?? 'orbi', true),
              child: const Text('Медленно'),
            ),
            TextButton(onPressed: audio.stop, child: const Text('Стоп')),
          ],
        ),
        ValueListenableBuilder(
          valueListenable: audio.playback,
          builder: (context, _, child) => Semantics(
            liveRegion: true,
            child: Text(
              audio.lastCharacter == (sample?.character ?? 'orbi') &&
                      audio.lastText == phrase &&
                      audio.lastProblem != null
                  ? audio.lastProblem!
                  : audioStatus,
            ),
          ),
        ),
        if (media['problem'] != null)
          Text(
            'Android: ${switch (media['problem']) {
              'focus' => 'аудиофокус недоступен',
              'muted' => 'медиа выключено',
              'asset' => 'не удалось открыть файл',
              'decoder' => 'ошибка декодера',
              _ => 'сбой звука',
            }}',
          ),
        if (Platform.isAndroid)
          TextButton(
            onPressed: () => VoiceService.settings('voiceSettings'),
            child: const Text('Установить голос Android'),
          ),
        const SectionTitle('Микрофон'),
        Text('Доступ: $permission'),
        if (capabilities.isNotEmpty)
          Text(
            'Локальный распознаватель: ${capabilities['offline'] == true ? 'есть' : 'нет'} · Системная служба: ${capabilities['system'] == true ? 'есть' : 'нет'}',
          ),
        if (Platform.isAndroid)
          SwitchListTile(
            value: consent,
            onChanged: setConsent,
            title: const Text('Разрешить системное распознавание через сеть'),
          ),
        ValueListenableBuilder(
          valueListenable: voice.status,
          builder: (context, state, child) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(state, semanticsLabel: state),
              FilledButton(
                onPressed: busy ? null : () => record(),
                child: Text(
                  voice.active
                      ? 'Остановить запись'
                      : 'Проверить микрофон офлайн',
                ),
              ),
              if (consent && !voice.active)
                OutlinedButton(
                  onPressed: busy ? null : () => record(network: true),
                  child: const Text('Проверить системное распознавание'),
                ),
            ],
          ),
        ),
        if (transcript.isNotEmpty) SelectableText(transcript),
        if (Platform.isAndroid)
          TextButton(
            onPressed: () => VoiceService.settings('appSettings'),
            child: const Text('Разрешения приложения Android'),
          ),
        TextButton(
          onPressed: busy ? null : refresh,
          child: const Text('Обновить данные устройства'),
        ),
      ]),
    );
  }
}
