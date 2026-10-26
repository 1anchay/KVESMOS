import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'recorded_speech.dart';

typedef ReadAudioSetting = Future<String?> Function(String);
typedef WriteAudioSetting = Future<void> Function(String, String);

class AudioPreferences {
  final bool speech, effects, reactions;
  final double speechVolume, effectsVolume;
  const AudioPreferences({
    this.speech = true,
    this.effects = true,
    this.reactions = true,
    this.speechVolume = .85,
    this.effectsVolume = .55,
  });
  AudioPreferences copyWith({
    bool? speech,
    bool? effects,
    bool? reactions,
    double? speechVolume,
    double? effectsVolume,
  }) => AudioPreferences(
    speech: speech ?? this.speech,
    effects: effects ?? this.effects,
    reactions: reactions ?? this.reactions,
    speechVolume: speechVolume ?? this.speechVolume,
    effectsVolume: effectsVolume ?? this.effectsVolume,
  );
  String encode() => jsonEncode({
    'speech': speech,
    'effects': effects,
    'reactions': reactions,
    'speechVolume': speechVolume,
    'effectsVolume': effectsVolume,
  });
  factory AudioPreferences.decode(String? raw) {
    try {
      final j = jsonDecode(raw ?? '{}') as Map;
      double volume(String key, double fallback) =>
          j[key] is num ? (j[key] as num).toDouble().clamp(0, 1) : fallback;
      return AudioPreferences(
        speech: j['speech'] != false,
        effects: j['effects'] != false,
        reactions: j['reactions'] != false,
        speechVolume: volume('speechVolume', .85),
        effectsVolume: volume('effectsVolume', .55),
      );
    } catch (_) {
      return const AudioPreferences();
    }
  }
}

class CharacterVoiceProfile {
  final String id, name;
  final double rate, pitch;
  const CharacterVoiceProfile(this.id, this.name, this.rate, this.pitch);
  static const all = [
    CharacterVoiceProfile('orbi', 'Орби', .45, 1.02),
    CharacterVoiceProfile('zig_quartz', 'Зиг Кварц', .48, 1.05),
    CharacterVoiceProfile('miko', 'Мико', .41, 1.03),
    CharacterVoiceProfile('reyvo', 'Рэйво', .47, 1.00),
    CharacterVoiceProfile('aster', 'Астэр', .41, .98),
    CharacterVoiceProfile('vespa', 'Веспа', .43, 1.00),
    CharacterVoiceProfile('pixie', 'Пикси', .47, 1.06),
    CharacterVoiceProfile('nox', 'Нокс', .39, .94),
    CharacterVoiceProfile('fox_scholar', 'Профессор-лис', .42, .97),
  ];
  static CharacterVoiceProfile forId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}

class DeviceVoice {
  final String name, locale;
  final bool? networkRequired;
  final String? gender;
  const DeviceVoice(
    this.name,
    this.locale,
    this.networkRequired, {
    this.gender,
  });
  String get key => '$locale|$name';
  bool supports(String requested) =>
      locale.replaceAll('_', '-').toLowerCase().split('-').first ==
      requested.toLowerCase().split('-').first;
}

abstract class TtsBackend {
  Future<List<DeviceVoice>> voices();
  Future<void> configure(
    DeviceVoice voice,
    double rate,
    double pitch,
    double volume,
  );
  Future<bool> speak(String text);
  Future<void> stop();
}

abstract interface class TtsPlaybackEvents {
  ValueListenable<bool> get playing;
}

abstract interface class TtsFailureEvents {
  ValueListenable<String?> get failure;
}

class SystemTtsBackend
    implements TtsBackend, TtsPlaybackEvents, TtsFailureEvents {
  final FlutterTts tts = FlutterTts();
  @override
  final ValueNotifier<bool> playing = ValueNotifier<bool>(false);
  @override
  final ValueNotifier<String?> failure = ValueNotifier<String?>(null);
  bool _active = false;
  SystemTtsBackend() {
    void release() {
      _active = false;
      playing.value = false;
      SoundEffectsService.channel
          .invokeMethod<void>('speechFinished')
          .catchError((_) {});
    }

    tts.setCompletionHandler(release);
    tts.setStartHandler(() {
      if (_active) playing.value = true;
    });
    tts.setCancelHandler(release);
    tts.setErrorHandler((_) {
      failure.value =
          'Системный голос прервал озвучку. Повторите попытку или прочитайте фразу.';
      release();
    });
  }
  @override
  Future<List<DeviceVoice>> voices() async {
    final raw = await tts.getVoices;
    if (raw is! List) return [];
    return [
      for (final v in raw)
        if (v is Map &&
            v['name'] is String &&
            v['locale'] is String &&
            !'${v['features']}'.contains('notInstalled'))
          DeviceVoice(
            v['name'],
            v['locale'],
            v['network_required'] == null
                ? null
                : [
                    'true',
                    '1',
                  ].contains('${v['network_required']}'.toLowerCase()),
            gender: v['gender']?.toString().toLowerCase(),
          ),
    ];
  }

  @override
  Future<void> configure(
    DeviceVoice voice,
    double rate,
    double pitch,
    double volume,
  ) async {
    if (Platform.isIOS) {
      await tts.setSharedInstance(true);
      await tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, []);
    }
    await tts.setLanguage(voice.locale);
    await tts.setVoice({'name': voice.name, 'locale': voice.locale});
    await tts.setSpeechRate(rate);
    await tts.setPitch(pitch);
    await tts.setVolume(volume);
    await tts.awaitSpeakCompletion(false);
  }

  @override
  Future<bool> speak(String text) async {
    failure.value = null;
    _active = true;
    return await tts.speak(text) == 1;
  }

  @override
  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    playing.value = false;
    await tts.stop();
  }
}

/// Stable per-locale assignments to installed voices; personality is subtle.
/// No network-only voice is selected. Unknown availability is disclosed in UI.
class CharacterVoiceService {
  static const mappingKey = 'kvesmos.audio.voices.v1';
  final TtsBackend backend;
  final ReadAudioSetting read;
  final WriteAudioSetting write;
  List<DeviceVoice> available = [];
  Map<String, String> assignments = {};
  bool scanned = false;
  int _generation = 0;
  Future<void> _queue = Future.value();
  CharacterVoiceService(this.read, this.write, {TtsBackend? backend})
    : backend = backend ?? SystemTtsBackend();
  Future<void> refresh() async {
    try {
      final raw = jsonDecode(await read(mappingKey) ?? '{}');
      if (raw is Map) assignments = raw.map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      assignments = {};
    }
    try {
      available =
          (await backend.voices().timeout(
              const Duration(seconds: 5),
            )).where((v) => v.networkRequired != true).toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      for (final locale in ['en-US', 'ru-RU']) {
        final pool = available.where((v) => v.supports(locale)).toList();
        for (final p in CharacterVoiceProfile.all) {
          final key = '${p.id}|$locale';
          if (pool.isEmpty) {
            assignments.remove(key);
            continue;
          }
          if (pool.any((v) => v.key == assignments[key])) continue;
          final used = assignments.entries
              .where((e) => e.key.endsWith('|$locale'))
              .map((e) => e.value)
              .toList();
          pool.sort((a, b) {
            // Prefer reported metadata, never infer gender from a voice name.
            if (p.id == 'vespa' || p.id == 'pixie') {
              final gender =
                  (b.gender == 'female' ? 1 : 0) -
                  (a.gender == 'female' ? 1 : 0);
              if (gender != 0) return gender;
            }
            final count = used
                .where((v) => v == a.key)
                .length
                .compareTo(used.where((v) => v == b.key).length);
            if (count != 0) return count;
            final exact =
                (b.locale == locale ? 1 : 0) - (a.locale == locale ? 1 : 0);
            return exact != 0 ? exact : a.key.compareTo(b.key);
          });
          assignments[key] = pool.first.key;
        }
      }
      await write(mappingKey, jsonEncode(assignments));
    } catch (_) {
      available = [];
    }
    scanned = true;
  }

  /// Count actual distinct installed voices, not character presets.
  int distinctVoiceCount(String locale) => available
      .where((voice) => voice.supports(locale))
      .map((voice) => voice.key)
      .toSet()
      .length;

  DeviceVoice? voiceFor(String character, String locale) {
    final key = assignments['$character|$locale'];
    return available
        .where((v) => v.key == key && v.supports(locale))
        .firstOrNull;
  }

  Future<bool> speak(
    String text, {
    String character = 'orbi',
    String locale = 'en-US',
    bool slow = false,
    double volume = .85,
  }) {
    final ticket = ++_generation;
    final work = _queue.then((_) async {
      if (ticket != _generation) return false;
      try {
        await backend.stop().timeout(const Duration(seconds: 2));
        if (!scanned || available.isEmpty) await refresh();
        if (ticket != _generation) return false;
        final voice = voiceFor(character, locale);
        if (voice == null) return false;
        final profile = CharacterVoiceProfile.forId(character);
        await backend
            .configure(
              voice,
              slow ? profile.rate * .72 : profile.rate,
              profile.pitch,
              volume.clamp(0, 1),
            )
            .timeout(const Duration(seconds: 4));
        if (ticket != _generation) return false;
        return await backend.speak(text).timeout(const Duration(seconds: 3));
      } catch (_) {
        return false;
      }
    });
    _queue = work.then((_) {});
    return work;
  }

  Future<void> stop() async {
    _generation++;
    try {
      await backend.stop();
    } catch (_) {
      /* Text mode remains available. */
    }
  }
}

enum SoundEffect {
  correct,
  incorrect,
  xp,
  complete,
  achievement,
  chest,
  rare,
  tap,
}

class SoundEffectsService {
  static const channel = MethodChannel('dev.orbitwords/learning_audio');
  DateTime? _last;
  DateTime? _protectedUntil;
  Future<void> prepare() async {
    try {
      await channel
          .invokeMethod<void>('prepare')
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      /* Unsupported platform. */
    }
  }

  Future<bool> play(SoundEffect effect, double volume) async {
    final now = DateTime.now();
    if (effect == SoundEffect.tap && _protectedUntil?.isAfter(now) == true) {
      return false;
    }
    if (_last != null &&
        now.difference(_last!) < const Duration(milliseconds: 90)) {
      return false;
    }
    _last = now;
    _protectedUntil = now.add(
      Duration(milliseconds: effect == SoundEffect.tap ? 120 : 700),
    );
    try {
      return await channel.invokeMethod<bool>('play', {
            'effect': effect.name,
            'volume':
                (volume *
                        (effect == SoundEffect.tap
                            ? .45
                            : effect == SoundEffect.incorrect
                            ? .65
                            : .85))
                    .clamp(0, 1),
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await channel.invokeMethod<void>('stop');
    } catch (_) {
      /* No player. */
    }
  }
}

/// One owner for TTS and effects. New requests cancel old playback, not queue it.
enum SpeechSource { recording, system }

class SpeechPlayback {
  final String character;
  final SpeechSource source;
  final bool playing;
  final bool paused;
  const SpeechPlayback(
    this.character,
    this.source,
    this.playing, {
    this.paused = false,
  });
}

class LearningAudio {
  static const preferencesKey = 'kvesmos.audio.preferences.v1';
  final ReadAudioSetting read;
  final WriteAudioSetting write;
  late final CharacterVoiceService voices;
  final SoundEffectsService effects;
  final RecordedSpeechBackend recordedPlayer;
  RecordedSpeechCatalog recordings;
  final playback = ValueNotifier<SpeechPlayback?>(null);
  SpeechSource? lastSource;
  String? lastCharacter, lastText;
  String? _speakingCharacter;
  int? _recordingRequest;
  AudioPreferences preferences = const AudioPreferences();
  String? lastProblem;
  int _generation = 0;
  LearningAudio(
    this.read,
    this.write, {
    TtsBackend? backend,
    SoundEffectsService? effects,
    RecordedSpeechBackend? recordedPlayer,
    this.recordings = const RecordedSpeechCatalog(),
  }) : effects = effects ?? SoundEffectsService(),
       recordedPlayer = recordedPlayer ?? NativeRecordedSpeech() {
    voices = CharacterVoiceService(read, write, backend: backend);
    final events = voices.backend;
    if (events is TtsPlaybackEvents) {
      final playingEvents = (events as TtsPlaybackEvents).playing;
      playingEvents.addListener(() {
        final character = _speakingCharacter;
        if (character != null && lastSource == SpeechSource.system) {
          playback.value = SpeechPlayback(
            character,
            SpeechSource.system,
            playingEvents.value,
          );
        }
      });
    }
    if (events is TtsFailureEvents) {
      final failures = (events as TtsFailureEvents).failure;
      failures.addListener(() {
        if (_speakingCharacter != null &&
            lastSource == SpeechSource.system &&
            failures.value != null) {
          lastProblem = failures.value;
          playback.value = null;
        }
      });
    }
  }
  Future<void> initialize() async {
    voices.scanned = false;
    preferences = AudioPreferences.decode(await read(preferencesKey));
    try {
      if (recordings.recordings.isEmpty) {
        recordings = await RecordedSpeechCatalog.load();
      }
    } catch (_) {
      /* TTS fallback remains available. */
    }
    SoundEffectsService.channel.setMethodCallHandler((call) async {
      if (call.method == 'interrupted') await stop();
      if ((call.method == 'recordingFinished' ||
              call.method == 'recordingFailed') &&
          call.arguments == _recordingRequest) {
        _recordingRequest = null;
        if (call.method == 'recordingFailed') {
          lastProblem =
              'Запись прервалась. Повторите прослушивание или прочитайте текст.';
        }
        playback.value = null;
      }
    });
    await effects.prepare();
  }

  Future<void> save(AudioPreferences value) async {
    await write(preferencesKey, value.encode());
    preferences = value;
    await stop();
  }

  Future<bool> speak(
    String text, {
    String character = 'orbi',
    String locale = 'en-US',
    bool slow = false,
  }) async {
    lastProblem = null;
    lastSource = null;
    lastCharacter = character;
    lastText = text;
    _speakingCharacter = null;
    _recordingRequest = null;
    playback.value = null;
    final ticket = ++_generation;
    await voices.stop();
    await recordedPlayer.stop();
    await effects.stop();
    if (ticket != _generation) return false;
    if (!preferences.speech || preferences.speechVolume == 0) {
      lastProblem = !preferences.speech
          ? 'Озвучка выключена в настройках KVESMOS.'
          : 'Громкость речи в KVESMOS равна нулю.';
      return false;
    }
    try {
      if (await SoundEffectsService.channel.invokeMethod<bool>('allowSpeech') !=
          true) {
        lastProblem =
            'Проверьте громкость мультимедиа. Если звук занят другим приложением, повторите прослушивание.';
        return false;
      }
    } catch (_) {
      lastProblem = 'Системный аудиоплеер недоступен. Фразу можно прочитать.';
      return false;
    }
    if (ticket != _generation) return false;
    final recording = recordings.find(character, locale, text);
    if (recording != null) {
      try {
        _recordingRequest = ticket;
        final started = await recordedPlayer.play(
          recording,
          slow: slow,
          volume: preferences.speechVolume,
          request: ticket,
        );
        if (ticket != _generation) return false;
        if (started) {
          lastSource = SpeechSource.recording;
          playback.value = SpeechPlayback(
            character,
            SpeechSource.recording,
            _recordingRequest == ticket,
          );
          return true;
        }
      } catch (_) {
        /* A broken/missing clip falls back to an installed voice. */
      }
      if (ticket != _generation) return false;
      _recordingRequest = null;
      try {
        if (await SoundEffectsService.channel.invokeMethod<bool>(
              'allowSpeech',
            ) !=
            true) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    if (ticket != _generation) return false;
    _speakingCharacter = character;
    lastSource = SpeechSource.system;
    playback.value = SpeechPlayback(character, SpeechSource.system, false);
    final ok = await voices.speak(
      text,
      character: character,
      locale: locale,
      slow: slow,
      volume: preferences.speechVolume,
    );
    if (!ok && ticket == _generation) {
      playback.value = null;
      lastProblem = voices.voiceFor(character, locale) == null
          ? 'Нет готового ${locale.startsWith('en') ? 'английского' : 'русского'} голоса. Установите офлайн-пакет в настройках синтеза речи Android и повторите прослушивание.'
          : 'Синтез речи не запустил фразу. Проверьте голос в настройках синтеза речи устройства.';
    }
    return ok && ticket == _generation;
  }

  Future<bool> play(SoundEffect effect) async {
    if (!preferences.effects || preferences.effectsVolume == 0) return false;
    final ticket = ++_generation;
    _speakingCharacter = null;
    _recordingRequest = null;
    playback.value = null;
    await voices.stop();
    await recordedPlayer.stop();
    if (ticket != _generation ||
        !preferences.effects ||
        preferences.effectsVolume == 0) {
      return false;
    }
    return effects.play(effect, preferences.effectsVolume);
  }

  Future<void> stop() async {
    _generation++;
    _speakingCharacter = null;
    _recordingRequest = null;
    playback.value = null;
    await voices.stop();
    await recordedPlayer.stop();
    await effects.stop();
  }

  Future<bool> pauseOrResume() async {
    final current = playback.value, player = recordedPlayer;
    if (current == null ||
        current.source != SpeechSource.recording ||
        player is! PausableRecordedSpeech) {
      return false;
    }
    final ticket = _generation;
    try {
      final pausable = player as PausableRecordedSpeech;
      final ok = current.paused
          ? await pausable.resume()
          : await pausable.pause();
      if (!ok || ticket != _generation || _recordingRequest == null) {
        return false;
      }
      playback.value = SpeechPlayback(
        current.character,
        current.source,
        current.paused,
        paused: !current.paused,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
