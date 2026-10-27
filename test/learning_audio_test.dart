import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/services/learning_audio.dart';

class FakeTts implements TtsBackend {
  List<DeviceVoice> installed = [
    const DeviceVoice('Local A', 'en-US', false),
    const DeviceVoice('Local B', 'en-US', false),
    const DeviceVoice('Русский', 'ru-RU', false),
    const DeviceVoice('Cloud', 'en-US', true),
  ];
  final spoken = <String>[];
  DeviceVoice? selected;
  double rate = 0, pitch = 0, volume = 0;
  int stops = 0;
  bool broken = false;
  Completer<void>? block;
  @override
  Future<List<DeviceVoice>> voices() async {
    if (broken) throw StateError('No engine');
    return installed;
  }

  @override
  Future<void> configure(
    DeviceVoice voice,
    double rate,
    double pitch,
    double volume,
  ) async {
    selected = voice;
    this.rate = rate;
    this.pitch = pitch;
    this.volume = volume;
    if (block != null) await block!.future;
  }

  @override
  Future<bool> speak(String text) async {
    spoken.add(text);
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> storage;
  late FakeTts backend;
  late CharacterVoiceService service;
  Future<String?> read(String key) async => storage[key];
  Future<void> write(String key, String value) async {
    storage[key] = value;
  }

  setUp(() {
    storage = {};
    backend = FakeTts();
    service = CharacterVoiceService(read, write, backend: backend);
  });
  test(
    'different installed voices are balanced, locale-correct and stable on reopening',
    () async {
      await service.refresh();
      expect(service.available, hasLength(3));
      expect(
        service.voiceFor('orbi', 'en-US')!.name,
        isNot(service.voiceFor('zig_quartz', 'en-US')!.name),
      );
      final before = Map.of(service.assignments);
      final reopened = CharacterVoiceService(read, write, backend: backend);
      await reopened.refresh();
      expect(reopened.assignments, before);
      for (final p in CharacterVoiceProfile.all) {
        expect(reopened.voiceFor(p.id, 'en-US')!.locale, 'en-US');
        expect(reopened.voiceFor(p.id, 'ru-RU')!.locale, 'ru-RU');
      }
    },
  );
  test(
    'female metadata is preferred for Vespa when supplied by the engine',
    () async {
      backend.installed = [
        const DeviceVoice('A', 'en-US', false, gender: 'male'),
        const DeviceVoice('B', 'en-US', false, gender: 'female'),
      ];
      await service.refresh();
      expect(service.voiceFor('vespa', 'en-US')!.gender, 'female');
      expect(service.voiceFor('pixie', 'en-US')!.gender, 'female');
    },
  );
  test(
    'removed voices remap safely; one or zero local voices are honest fallbacks',
    () async {
      await service.refresh();
      backend.installed = [const DeviceVoice('One', 'en-GB', false)];
      await service.refresh();
      expect(service.assignments.values.toSet(), {'en-GB|One'});
      expect(await service.speak('Hello', locale: 'ru-RU'), false);
      expect(await service.speak('Hello'), true);
      backend.installed = [const DeviceVoice('Cloud', 'en-US', true)];
      await service.refresh();
      expect(await service.speak('Hello'), false);
      expect(service.available, isEmpty);
    },
  );
  test(
    'slow voice stays intelligible and uses requested locale and safe parameters',
    () async {
      expect(
        await service.speak('Hello', character: 'nox', slow: true, volume: .6),
        true,
      );
      expect(backend.rate, closeTo(.39 * .72, .001));
      expect(backend.pitch, inInclusiveRange(.94, 1.06));
      expect(backend.volume, .6);
      expect(
        await service.speak('Привет', character: 'vespa', locale: 'ru-RU'),
        true,
      );
      expect(backend.selected!.locale, 'ru-RU');
    },
  );
  test(
    'rapid switching and closing during configuration cancel stale phrases',
    () async {
      backend.block = Completer<void>();
      final old = service.speak('old');
      while (backend.selected == null) {
        await Future<void>.delayed(Duration.zero);
      }
      final latest = service.speak('latest');
      backend.block!.complete();
      expect(await old, false);
      expect(await latest, true);
      expect(backend.spoken, ['latest']);
      backend.selected = null;
      backend.block = Completer<void>();
      final closing = service.speak('after close');
      while (backend.selected == null) {
        await Future<void>.delayed(Duration.zero);
      }
      await service.stop();
      backend.block!.complete();
      expect(await closing, false);
      expect(backend.spoken, ['latest']);
    },
  );
  test(
    'missing engine and corrupt mapping use text mode without throwing',
    () async {
      storage[CharacterVoiceService.mappingKey] = 'broken json';
      expect(await service.speak('Hello'), true);
      storage.clear();
      backend.broken = true;
      await service.refresh();
      expect(await service.speak('Hello'), false);
    },
  );
  test(
    'audio preferences persist independently; sound requests stop speech and throttle bursts',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SoundEffectsService.channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SoundEffectsService.channel, null),
      );
      final audio = LearningAudio(read, write, backend: backend);
      await audio.initialize();
      expect(await audio.speak('Hello'), true);
      final stops = backend.stops;
      expect(await audio.play(SoundEffect.correct), true);
      expect(backend.stops, greaterThan(stops));
      expect(await audio.play(SoundEffect.incorrect), false);
      expect(calls.where((c) => c.method == 'play'), hasLength(1));
      await audio.save(
        const AudioPreferences(
          speech: false,
          effects: false,
          reactions: false,
          speechVolume: .3,
          effectsVolume: .2,
        ),
      );
      final reopened = LearningAudio(read, write, backend: backend);
      await reopened.initialize();
      expect(reopened.preferences.encode(), audio.preferences.encode());
      expect(await reopened.speak('muted'), false);
      expect(await reopened.play(SoundEffect.xp), false);
      expect(backend.spoken, ['Hello']);
      expect(
        jsonDecode(storage[LearningAudio.preferencesKey]!)['reactions'],
        false,
      );
      await reopened.stop();
    },
  );
  test(
    'system TTS adapter handles actual plugin voice metadata and method arguments',
    () async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('flutter_tts');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'getVoices') {
              return [
                {'name': 'Offline', 'locale': 'en-US', 'network_required': '0'},
                {'name': 'Online', 'locale': 'en-US', 'network_required': '1'},
                {
                  'name': 'Absent',
                  'locale': 'en-US',
                  'features': ['notInstalled'],
                },
              ];
            }
            return 1;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final adapter = SystemTtsBackend();
      final list = await adapter.voices();
      expect(list, hasLength(2));
      expect(list.last.networkRequired, true);
      await adapter.configure(list.first, .42, 1.02, .7);
      expect(await adapter.speak('Hello'), true);
      expect(calls.firstWhere((c) => c.method == 'setVoice').arguments, {
        'name': 'Offline',
        'locale': 'en-US',
      });
      expect(
        calls.firstWhere((c) => c.method == 'setLanguage').arguments,
        'en-US',
      );
      await adapter.stop();
    },
  );
  test(
    'eleven original earcons are sub-second PCM files and preferences tolerate bad input',
    () {
      for (final effect in SoundEffect.values) {
        final bytes = File(
          'assets/audio/effects/${effect.name}.wav',
        ).readAsBytesSync();
        expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
        expect(
          bytes.length,
          lessThan(44144),
        ); // <1 second, mono 22050 Hz PCM16.
        expect(bytes.length, greaterThan(1000));
      }
      expect(AudioPreferences.decode('broken').speech, true);
      expect(
        AudioPreferences.decode(
          '{"speechVolume":8,"effectsVolume":-1}',
        ).speechVolume,
        1,
      );
      expect(AudioPreferences.decode('{"effectsVolume":-1}').effectsVolume, 0);
    },
  );
}
