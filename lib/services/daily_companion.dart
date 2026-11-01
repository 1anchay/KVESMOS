import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../data/repository.dart';
import '../domain/languages.dart';
import '../domain/progress.dart';
import '../domain/reminders.dart';

/// Versioned, read-only snapshot is shared with Android RemoteViews and the
/// future WidgetKit adapter. The ledger in SQLite remains the only XP source.
class DailyCompanion {
  static const channel = MethodChannel('dev.orbitwords/daily_companion');
  static const settingsKey = 'kvesmos.reminders.v1';
  final LearningRepository repository;
  final notifications = FlutterLocalNotificationsPlugin();
  final launchCourse = ValueNotifier<String?>(null);
  ReminderPreferences preferences = const ReminderPreferences();
  bool available = false;
  DailyCompanion(this.repository);
  void _launch(String? id) {
    if (StudyCourse.all.any((c) => c.id == id)) launchCourse.value = id;
  }

  Future<void> initialize() async {
    preferences = ReminderPreferences.decode(
      await repository.setting(settingsKey),
    );
    try {
      await notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _launch(response.payload),
      );
      // Replace the earlier unconfigured periodic reminder; never carry its
      // opt-in across to the new policy without a user's explicit choice.
      await notifications.cancel(1);
      channel.setMethodCallHandler((call) async {
        if (call.method == 'openCourse') _launch(call.arguments as String?);
      });
      _launch(await channel.invokeMethod<String>('consumeLaunch'));
      final launch = await notifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _launch(launch?.notificationResponse?.payload);
      }
      available = true;
    } catch (_) {
      available = false;
    }
  }

  Future<bool> requestPermission() async {
    if (!available) await initialize();
    if (!available) return false;
    if (Platform.isAndroid) {
      return await notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<void> save(ReminderPreferences value) async {
    await repository.setSetting(settingsKey, value.encode());
    preferences = value;
  }

  Future<void> sync(int goal) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final events = await repository.allEvents();
    final courses = <String, dynamic>{};
    for (final c in StudyCourse.all) {
      final progress = ProgressSnapshot.fromEvents(
        events.where((e) => e.courseId == c.id),
      );
      courses[c.id] = {
        'name': c.name,
        'flag': c.flag,
        'dailyXp': progress.dailyXp,
      };
    }
    final snapshot = {
      'version': 1,
      'selectedCourse': repository.course.id,
      'goal': goal,
      'updatedAt': repository.now().toUtc().toIso8601String(),
      'courses': courses,
      'reminders': preferences.toJson(),
    };
    try {
      await channel.invokeMethod<void>('sync', jsonEncode(snapshot));
      if (Platform.isIOS && available) await _scheduleIOS(courses, goal);
    } catch (_) {
      /* Desktop/test adapters have no home widget. */
    }
  }

  Future<void> _scheduleIOS(Map<String, dynamic> courses, int goal) async {
    tzdata.initializeTimeZones();
    final zone = await channel.invokeMethod<String>('timezone');
    if (zone == null) return; // Never guess UTC for local reminders.
    tz.setLocalLocation(tz.getLocation(zone));
    for (var i = 0; i < 14; i++) {
      await notifications.cancel(1100 + i);
    }
    final now = tz.TZDateTime.now(tz.local);
    final xp = courses[preferences.courseId]['dailyXp'] as Map;
    for (var i = 0; i < 14; i++) {
      final date = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + i,
        preferences.minute ~/ 60,
        preferences.minute % 60,
      );
      if (!date.isAfter(now) ||
          !preferences.eligible(date, xp[dayKey(date)] ?? 0, goal)) {
        continue;
      }
      final c = StudyCourse.byId(preferences.courseId);
      await notifications.zonedSchedule(
        1100 + i,
        'Орби · ${c.name}',
        'Пять минут для новых слов сегодня?',
        date,
        const NotificationDetails(iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: c.id,
      );
    }
  }

  Future<bool> pinWidget() async {
    try {
      return await channel.invokeMethod<bool>('pinWidget') ?? false;
    } catch (_) {
      return false;
    }
  }
}
