import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  void Function(String)? _onError;
  void Function()? _onDone;
  Future<bool> listen(
    void Function(String) result,
    void Function(String) error, {
    String language = 'en',
    void Function()? onDone,
  }) async {
    try {
      _onError = error;
      _onDone = onDone;
      if (!await _speech.initialize(
        onError: (_) => _onError?.call(
          'Распознавание недоступно. Используйте ввод текста.',
        ),
        onStatus: (status) {
          if (status == SpeechToText.doneStatus) _onDone?.call();
        },
      )) {
        return false;
      }
      final locales = await _speech.locales();
      final matching = locales.where(
        (l) => l.localeId.split(RegExp('[-_]')).first == language,
      );
      if (matching.isEmpty) {
        return false;
      }
      await _speech.listen(
        onResult: (r) => result(r.recognizedWords),
        listenOptions: SpeechListenOptions(
          localeId: matching.first.localeId,
          listenFor: const Duration(seconds: 15),
          onDevice: true,
          partialResults: true,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    _onError = null;
    _onDone = null;
    try {
      await _speech.stop();
    } catch (_) {
      /* No active recognizer. */
    }
  }
}
