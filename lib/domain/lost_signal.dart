import 'dart:convert';

abstract final class LostSignalMission {
  static const id = 'lost_signal';
  static const rewardId = 'mission:v1:lost_signal:reward';
  static const objectives = [
    'Incoming transmission',
    'Find the blue door.',
    'Find the red key and the battery.',
    'Do you have the battery?',
    'Put the battery in the power unit.',
    'Press the green button.',
    'Power is back. Signal restored!',
  ];
  static const translations = [
    'Входящее сообщение',
    'Найди синюю дверь.',
    'Найди красный ключ и батарею.',
    'У тебя есть батарея?',
    'Помести батарею в блок питания.',
    'Нажми зелёную кнопку.',
    'Питание восстановлено. Связь работает!',
  ];
}

class LostSignalState {
  int phase, revision, attempts;
  String room, feedback;
  bool doorOpen, batteryInstalled, powered, completed, hint;
  final Set<String> inventory, inspected;
  final Map<String, int> errors;

  LostSignalState({
    this.phase = 0,
    this.revision = 0,
    this.attempts = 0,
    this.room = 'dock',
    this.feedback = '',
    this.doorOpen = false,
    this.batteryInstalled = false,
    this.powered = false,
    this.completed = false,
    this.hint = false,
    Set<String>? inventory,
    Set<String>? inspected,
    Map<String, int>? errors,
  }) : inventory = inventory ?? {},
       inspected = inspected ?? {},
       errors = errors ?? {};

  String get objective => LostSignalMission.objectives[phase];
  String get translation => LostSignalMission.translations[phase];

  String encode() => jsonEncode({
    'version': 1,
    'phase': phase,
    'revision': revision,
    'attempts': attempts,
    'room': room,
    'feedback': feedback,
    'doorOpen': doorOpen,
    'batteryInstalled': batteryInstalled,
    'powered': powered,
    'completed': completed,
    'hint': hint,
    'inventory': inventory.toList()..sort(),
    'inspected': inspected.toList()..sort(),
    'errors': errors,
  });

  factory LostSignalState.decode(String? raw) {
    if (raw == null) return LostSignalState();
    final value = jsonDecode(raw) as Map<String, dynamic>;
    if (value['version'] != 1) {
      throw StateError('Нужна более новая версия KVESMOS.');
    }
    return LostSignalState(
      phase: value['phase'],
      revision: value['revision'],
      attempts: value['attempts'],
      room: value['room'],
      feedback: value['feedback'],
      doorOpen: value['doorOpen'],
      batteryInstalled: value['batteryInstalled'],
      powered: value['powered'],
      completed: value['completed'],
      hint: value['hint'],
      inventory: Set<String>.from(value['inventory']),
      inspected: Set<String>.from(value['inspected']),
      errors: Map<String, int>.from(value['errors']),
    );
  }
}
