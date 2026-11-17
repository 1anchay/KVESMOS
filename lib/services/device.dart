import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/languages.dart';

class VoiceService {
  static const channel = MethodChannel('dev.orbitwords/learning_device');
  static const networkSetting = 'kvesmos.system_speech_consent.v1';
  static VoiceService? _owner;
  static int _sequence = 0;
  String? _unavailableOfflineLocale;
  String? _locale;
  bool _network = false;
  static final _speech = SpeechToText();
  int? _token;
  void Function(String)? _result, _error;
  VoidCallback? _done;
  final status = ValueNotifier<String>('Готов к записи');
  bool get active => _token != null;

  static Future<void> settings(String method) async {
    try {
      await channel.invokeMethod<Object?>(method);
    } on PlatformException {
      // Settings entry points vary between Android distributions.
    } on MissingPluginException {
      // Android settings are unavailable on other platforms.
    }
  }

  static Future<Map<String, dynamic>> capabilities() async =>
      await channel.invokeMapMethod<String, dynamic>('speechStatus') ?? {};

  static String explanation(String code) => switch (code) {
    'denied' || 'android_9' => 'Разрешите доступ к микрофону.',
    'blocked' =>
      'Доступ к микрофону заблокирован. Разрешите его в настройках приложения.',
    'service' => 'На устройстве нет доступной службы распознавания речи.',
    'offline' =>
      'Локальное распознавание недоступно. В проверке звука можно разрешить системное распознавание или продолжить текстом.',
    'locale' || 'android_12' => 'Распознаватель не поддерживает этот язык.',
    'android_13' => 'Пакет распознавания для этого языка не установлен.',
    'timeout' || 'android_6' => 'Речь не услышана. Попробуйте ещё раз.',
    'android_7' =>
      'Не удалось разобрать фразу. Попробуйте ещё раз или введите ответ.',
    'busy' ||
    'android_8' ||
    'android_10' => 'Распознавание занято. Повторите попытку.',
    'android_3' =>
      'Android не получил звук с микрофона. Проверьте системный доступ к микрофону.',
    'android_1' ||
    'android_2' => 'Служба распознавания сообщила об ошибке сети.',
    'interrupted' => 'Запись остановлена.',
    _ => 'Служба распознавания не смогла обработать запись ($code).',
  };

  Future<bool> listen(
    void Function(String) result,
    void Function(String) error, {
    String language = 'en',
    bool allowNetwork = false,
    bool testNetwork = false,
    void Function()? onDone,
  }) async {
    if (_owner != null) {
      error(explanation('busy'));
      return false;
    }
    final id = ++_sequence;
    _owner = this;
    _token = id;
    _result = result;
    _error = error;
    _done = onDone;
    status.value = 'Запускаю микрофон…';
    final locale = StudyCourse.byId('ru-$language').locale;
    _locale = locale;
    _network = false;
    try {
      if (!Platform.isAndroid) {
        if (!await _speech.initialize(
          onError: (e) => _owner?._fail(e.errorMsg),
          onStatus: (s) {
            if (s == SpeechToText.doneStatus) _owner?._finish('Готово');
          },
        )) {
          _fail('service');
          return false;
        }
        if (_token != id) return false;
        await _speech.listen(
          onResult: (r) {
            if (_token == id) result(r.recognizedWords);
          },
          listenOptions: SpeechListenOptions(
            localeId: locale,
            listenFor: const Duration(seconds: 15),
            onDevice: true,
            partialResults: true,
          ),
        );
        if (_token == id) status.value = 'Слушаю…';
        return _token == id;
      }
      channel.setMethodCallHandler((call) async {
        if (call.method != 'speechEvent') return;
        final data = Map<String, dynamic>.from(call.arguments as Map);
        final owner = _owner;
        if (owner == null || owner._token != data['token']) return;
        owner._event(data['state'] as String, data['words'] as String?);
      });
      final permission = await channel.invokeMethod<String>('requestMic');
      if (_token != id) return false;
      if (permission != 'granted') {
        _fail(permission ?? 'denied');
        return false;
      }
      final args = {'token': id, 'locale': locale};
      _network =
          allowNetwork && (testNetwork || _unavailableOfflineLocale == locale);
      var started = await channel.invokeMethod<String>('startSpeech', {
        ...args,
        'network': _network,
      });
      if (_token != id) return false;
      if (allowNetwork && started == 'offline') {
        _network = true;
        started = await channel.invokeMethod<String>('startSpeech', {
          ...args,
          'network': true,
        });
      }
      if (_token != id) return false;
      if (started != 'started') {
        _fail(started ?? 'service');
        return false;
      }
      return true;
    } catch (_) {
      if (_token == id) _fail('service');
      return false;
    }
  }

  void _event(String state, String? words) {
    if (words != null && words.isNotEmpty) _result?.call(words);
    switch (state) {
      case 'listening' || 'speaking':
        status.value = 'Слушаю…';
      case 'partial':
        status.value = 'Слушаю · есть промежуточный текст';
      case 'processing':
        status.value = 'Распознаю…';
      case 'final':
        if (words == null || words.isEmpty) {
          _fail('android_7');
        } else {
          _finish('Фраза распознана');
        }
      default:
        _fail(state);
    }
  }

  void _fail(String code) {
    if (!_network && (code == 'android_12' || code == 'android_13')) {
      _unavailableOfflineLocale = _locale;
    }
    final message = explanation(code);
    final notify = _error;
    debugPrint('KVESMOS speech: $code');
    _finish(message);
    notify?.call(message);
  }

  void _finish(String message) {
    final done = _done;
    _token = null;
    _result = null;
    _error = null;
    _done = null;
    if (_owner == this) _owner = null;
    status.value = message;
    done?.call();
  }

  Future<void> stop({bool keepResult = false}) async {
    final id = _token;
    if (id == null) return;
    if (!keepResult) _finish('Запись остановлена');
    try {
      if (Platform.isAndroid) {
        await channel.invokeMethod<void>('stopSpeech', {
          'token': id,
          'cancel': !keepResult,
        });
      } else if (keepResult) {
        await _speech.stop();
      } else {
        await _speech.cancel();
      }
    } catch (_) {
      if (_token == id) _fail('interrupted');
    }
  }
}
