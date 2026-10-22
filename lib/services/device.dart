import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  Future<bool> listen(
    void Function(String) result,
    void Function(String) error,
  ) async {
    try {
      if (!await _speech.initialize(
        onError: (_) =>
            error('Распознавание недоступно. Используйте ввод текста.'),
      )) {
        return false;
      }
      final locales = await _speech.locales();
      final english = locales.where((l) => l.localeId.startsWith('en'));
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

class ReminderService {
  final _notifications = FlutterLocalNotificationsPlugin();
  Future<void> _initialize() async {
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<bool> enable() async {
    await _initialize();
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted =
        await android?.requestNotificationsPermission() ??
        await ios?.requestPermissions(alert: true, sound: true) ??
        false;
    if (!granted) {
      return false;
    }
    await _notifications.periodicallyShow(
      1,
      'Новая орбита ждёт',
      'Несколько слов сегодня — ещё один шаг к новому миру.',
      RepeatInterval.daily,
      const NotificationDetails(
        android: AndroidNotificationDetails('study', 'Напоминания об учёбе'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }

  Future<void> disable() async {
    await _initialize();
    await _notifications.cancelAll();
  }
}
