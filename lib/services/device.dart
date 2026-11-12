import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  Future<bool> listen(
    void Function(String) result,
    void Function(String) error, {
    String language = 'en',
  }) async {
    try {
      if (!await _speech.initialize(
        onError: (_) =>
            error('Распознавание недоступно. Используйте ввод текста.'),
      )) {
        return false;
      }
      final locales = await _speech.locales();
      final english = locales.where((l) => l.localeId.startsWith(language));
      if (english.isEmpty) {
        return false;
      }
      await _speech.listen(
        onResult: (r) => result(r.recognizedWords),
        listenOptions: SpeechListenOptions(
          localeId: english.first.localeId,
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
    try {
      await _speech.stop();
    } catch (_) {
      /* No active recognizer. */
    }
  }
}
