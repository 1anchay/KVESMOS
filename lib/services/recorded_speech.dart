import 'dart:convert';
import 'package:flutter/services.dart';

/// Only bundled, rights-cleared recordings are eligible. No URL/download path.
class SpeechRecording {
  final String character, locale, text, asset, performer, licenseAsset;
  final String? slowAsset;
  const SpeechRecording({
    required this.character,
    required this.locale,
    required this.text,
    required this.asset,
    required this.performer,
    required this.licenseAsset,
    this.slowAsset,
  });

  factory SpeechRecording.fromJson(Map<String, dynamic> j) {
    String path(String key, String prefix) {
      final value = j[key] as String;
      if (!value.startsWith(prefix) ||
          value.contains('..') ||
          value.contains('\\') ||
          value.contains(':')) {
        throw FormatException('Invalid bundled speech path: $key');
      }
      return value;
    }

    if (j['redistributionApproved'] != true ||
        '${j['performer'] ?? ''}'.trim().isEmpty ||
        '${j['text'] ?? ''}'.trim().isEmpty) {
      throw const FormatException(
        'Recording requires text, performer and redistribution approval',
      );
    }
    return SpeechRecording(
      character: j['character'],
      locale: j['locale'],
      text: j['text'],
      asset: path('asset', 'assets/audio/voices/'),
      slowAsset: j['slowAsset'] == null
          ? null
          : path('slowAsset', 'assets/audio/voices/'),
      performer: j['performer'],
      licenseAsset: path('licenseAsset', 'assets/audio/voices/licenses/'),
    );
  }
}

class RecordedSpeechCatalog {
  final List<SpeechRecording> recordings;
  const RecordedSpeechCatalog([this.recordings = const []]);
  factory RecordedSpeechCatalog.decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Unsupported voice manifest');
    }
    final recordings = (json['recordings'] as List)
        .map((v) => SpeechRecording.fromJson(Map<String, dynamic>.from(v)))
        .toList();
    final keys = recordings
        .map((v) => '${v.character}|${v.locale}|${v.text.trim()}')
        .toSet();
    if (keys.length != recordings.length) {
      throw const FormatException('Duplicate voice recording');
    }
    return RecordedSpeechCatalog(recordings);
  }
  static Future<RecordedSpeechCatalog> load() async =>
      RecordedSpeechCatalog.decode(
        await rootBundle.loadString('assets/audio/voices/manifest.json'),
      );
  SpeechRecording? find(String character, String locale, String text) =>
      recordings
          .where(
            (r) =>
                r.character == character &&
                r.locale == locale &&
                r.text.trim() == text.trim(),
          )
          .firstOrNull;
}

abstract class RecordedSpeechBackend {
  Future<bool> play(
    SpeechRecording clip, {
    required bool slow,
    required double volume,
    required int request,
  });
  Future<void> stop();
}

abstract interface class PausableRecordedSpeech {
  Future<bool> pause();
  Future<bool> resume();
}

class NativeRecordedSpeech
    implements RecordedSpeechBackend, PausableRecordedSpeech {
  static const channel = MethodChannel('dev.orbitwords/learning_audio');
  bool _active = false;
  @override
  Future<bool> pause() async =>
      _active && await channel.invokeMethod<bool>('pauseSpeech') == true;
  @override
  Future<bool> resume() async =>
      _active && await channel.invokeMethod<bool>('resumeSpeech') == true;
  @override
  Future<bool> play(
    SpeechRecording clip, {
    required bool slow,
    required double volume,
    required int request,
  }) async {
    _active = true;
    try {
      final started =
          await channel.invokeMethod<bool>('playSpeech', {
            'asset': slow && clip.slowAsset != null
                ? clip.slowAsset
                : clip.asset,
            'rate': slow && clip.slowAsset == null ? .8 : 1.0,
            'volume': volume,
            'request': request,
          }) ??
          false;
      if (!started) _active = false;
      return started;
    } catch (_) {
      _active = false;
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    try {
      await channel.invokeMethod<void>('stopSpeech');
    } catch (_) {
      /* Optional player. */
    }
  }
}
