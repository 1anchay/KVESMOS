import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/services/recorded_speech.dart';
import 'package:orbitwords/ui/dialogue_scene.dart';
import 'learning_audio_test.dart' show FakeTts;

class FakeRecordingPlayer
    implements RecordedSpeechBackend, PausableRecordedSpeech {
  bool works = true;
  int stops = 0;
  final requests = <int>[];
  bool? lastSlow;
  Completer<bool>? pending;
  bool paused = false;
  @override
  Future<bool> pause() async {
    paused = true;
    return true;
  }

  @override
  Future<bool> resume() async {
    paused = false;
    return true;
  }

  @override
  Future<bool> play(
    SpeechRecording clip, {
    required bool slow,
    required double volume,
    required int request,
  }) async {
    requests.add(request);
    lastSlow = slow;
    return pending == null ? works : await pending!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class EventTts extends FakeTts implements TtsPlaybackEvents {
  @override
  final ValueNotifier<bool> playing = ValueNotifier(false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const clip = SpeechRecording(
    character: 'orbi',
    locale: 'en-US',
    text: 'Hello!',
    asset: 'assets/audio/voices/test.wav',
    performer: 'Test actor',
    licenseAsset: 'assets/audio/voices/licenses/test.txt',
  );
  late FakeRecordingPlayer player;
  late EventTts tts;
  late LearningAudio audio;
  Future<void> event(String method, int id) async {
    final done = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          SoundEffectsService.channel.name,
          const StandardMethodCodec().encodeMethodCall(MethodCall(method, id)),
          (_) => done.complete(),
        );
    await done.future;
  }

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SoundEffectsService.channel,
          (_) async => true,
        );
    player = FakeRecordingPlayer();
    tts = EventTts();
    audio = LearningAudio(
      (_) async => null,
      (_, _) async {},
      backend: tts,
      recordedPlayer: player,
      recordings: const RecordedSpeechCatalog([clip]),
    );
    await audio.initialize();
  });
  tearDown(() async {
    await audio.stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SoundEffectsService.channel, null);
    SoundEffectsService.channel.setMethodCallHandler(null);
  });
  test(
    'course locale selects only its offline voice, never an English clip',
    () async {
      tts.installed.addAll(const [
        DeviceVoice('Español', 'es-ES', false),
        DeviceVoice('Deutsch', 'de-DE', false),
      ]);
      await audio.voices.refresh();
      for (final locale in ['es-ES', 'de-DE']) {
        audio.studyLocale = locale;
        // Deliberately use text present in the English recording catalogue.
        expect(await audio.speak('Hello!'), true);
        expect(player.requests, isEmpty);
        expect(audio.lastSource, SpeechSource.system);
        expect(tts.selected?.locale, locale);
        expect(await audio.speak('Hello!', slow: true), true);
        expect(tts.selected?.locale, locale);
      }
      tts.installed.removeWhere((v) => v.locale == 'de-DE');
      await audio.voices.refresh();
      expect(await audio.speak('Hello!'), false);
      expect(player.requests, isEmpty);
      expect(audio.lastProblem, contains('немецкого'));
      audio.studyLocale = 'en-US';
      expect(await audio.speak('Hello!'), true);
      expect(audio.lastSource, SpeechSource.recording);
    },
  );
  testWidgets('dialogue playback follows the selected course language', (
    tester,
  ) async {
    tts.installed.addAll(const [
      DeviceVoice('Español', 'es-ES', false),
      DeviceVoice('Deutsch', 'de-DE', false),
    ]);
    await audio.voices.refresh();
    for (final entry in {'es-ES': 'Hola.', 'de-DE': 'Guten Tag.'}.entries) {
      audio.studyLocale = entry.key;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DialogueScene(scene: 'Орби: ${entry.value}', audio: audio),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Послушать: Орби'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(tts.selected?.locale, entry.key, reason: audio.lastProblem);
      expect(tts.spoken.last, entry.value);
    }
  });
  test(
    'inactive native recording player does not block ordinary lesson transitions',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SoundEffectsService.channel, (call) async {
            calls.add(call);
            return true;
          });
      final native = NativeRecordedSpeech();
      await native.stop();
      expect(calls, isEmpty);
      expect(
        await native.play(clip, slow: true, volume: .7, request: 42),
        true,
      );
      expect(calls.single.arguments, {
        'asset': clip.asset,
        'rate': .8,
        'volume': .7,
        'request': 42,
      });
      await native.stop();
      await native.stop();
      expect(calls.map((c) => c.method), ['playSpeech', 'stopSpeech']);
    },
  );
  test(
    'local recording wins, slow replay stops old phrase, stale completion is ignored',
    () async {
      expect(await audio.speak('Hello!'), true);
      expect(tts.spoken, isEmpty);
      expect(audio.lastSource, SpeechSource.recording);
      expect(audio.playback.value?.playing, true);
      final old = player.requests.single;
      expect(await audio.speak('Hello!', slow: true), true);
      expect(player.lastSlow, true);
      expect(player.stops, greaterThanOrEqualTo(2));
      await event('recordingFinished', old);
      expect(audio.playback.value?.playing, true);
      await event('recordingFinished', player.requests.last);
      expect(audio.playback.value, isNull);
    },
  );
  test(
    'failed clip falls back honestly and talking follows actual TTS events',
    () async {
      player.works = false;
      expect(await audio.speak('Hello!'), true);
      expect(audio.lastSource, SpeechSource.system);
      expect(audio.playback.value?.playing, false);
      tts.playing.value = true;
      expect(audio.playback.value?.playing, true);
      tts.playing.value = false;
      expect(audio.playback.value?.playing, false);
      expect(tts.spoken, ['Hello!']);
    },
  );
  test(
    'stop during local start cannot revive playback or trigger fallback',
    () async {
      player.pending = Completer<bool>();
      final request = audio.speak('Hello!');
      while (player.requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await audio.stop();
      player.pending!.complete(true);
      expect(await request, false);
      expect(audio.playback.value, isNull);
      expect(tts.spoken, isEmpty);
    },
  );
  test('muted audio and absent English voice keep a readable error', () async {
    await audio.save(const AudioPreferences(speech: false));
    expect(await audio.speak('Hello!'), false);
    expect(player.requests, isEmpty);
    expect(audio.lastProblem, contains('выключена'));
    await audio.save(const AudioPreferences());
    tts.installed = [];
    expect(await audio.speak('Other phrase'), false);
    expect(audio.lastProblem, contains('Нет готового'));
    expect(audio.playback.value, isNull);
  });
  test('selection stays quiet during speech; verdict cancels it', () async {
    expect(await audio.speak('Hello!'), true);
    final request = player.requests.single, stops = player.stops;
    expect(await audio.play(SoundEffect.tap), false);
    expect(player.stops, stops);
    expect(audio.playback.value?.playing, true);
    expect(await audio.play(SoundEffect.correct), true);
    expect(player.stops, greaterThan(stops));
    expect(audio.playback.value, isNull);
    await event('recordingFinished', request);
    expect(audio.playback.value, isNull);
  });
  test(
    'catalog rejects remote paths, duplicates and missing rights approval',
    () {
      final row = {
        'character': 'orbi',
        'locale': 'en-US',
        'text': 'Hello!',
        'asset': clip.asset,
        'performer': 'test',
        'licenseAsset': clip.licenseAsset,
        'redistributionApproved': true,
      };
      String pack(List<Map<String, Object>> rows) =>
          jsonEncode({'version': 1, 'recordings': rows});
      expect(
        RecordedSpeechCatalog.decode(
          pack([row]),
        ).find('orbi', 'en-US', 'Hello!'),
        isNotNull,
      );
      expect(
        () => RecordedSpeechCatalog.decode(pack([row, row])),
        throwsFormatException,
      );
      for (final path in [
        'https://example.com/a.wav',
        'assets/audio/voices/../private.wav',
        'assets/audio/voices/C:\\data',
      ]) {
        expect(
          () => RecordedSpeechCatalog.decode(
            pack([
              {...row, 'asset': path},
            ]),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => RecordedSpeechCatalog.decode(
          pack([
            {...row, 'redistributionApproved': false},
          ]),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'bundled manifest never advertises missing audio or license documents',
    () {
      final catalog = RecordedSpeechCatalog.decode(
        File('assets/audio/voices/manifest.json').readAsStringSync(),
      );
      for (final recording in catalog.recordings) {
        for (final path in [
          recording.asset,
          recording.licenseAsset,
          if (recording.slowAsset != null) recording.slowAsset!,
        ]) {
          expect(File(path).existsSync(), true, reason: path);
          expect(File(path).lengthSync(), greaterThan(0), reason: path);
        }
      }
    },
  );
  test(
    'recording pause resumes the same request and stop prevents stale resume',
    () async {
      expect(await audio.speak('Hello!', character: 'orbi'), true);
      final requests = player.requests.length;
      expect(await audio.pauseOrResume(), true);
      expect(audio.playback.value!.paused, true);
      expect(player.paused, true);
      expect(await audio.pauseOrResume(), true);
      expect(audio.playback.value!.playing, true);
      expect(player.requests, hasLength(requests));
      await audio.stop();
      expect(await audio.pauseOrResume(), false);
    },
  );
}
