import 'dart:convert';

import '../domain/first_flight.dart';
import '../domain/knowledge.dart';
import '../domain/rewards.dart';
import 'knowledge_repository.dart';
import 'repository.dart';
import 'rewards_repository.dart';

class FirstFlightRepository {
  static const key = 'kvesmos.reboot.first-flight.v1';
  final LearningRepository learning;
  FirstFlightRepository(this.learning);

  Future<FirstFlight> read() async {
    final raw = await learning.setting(key);
    try {
      return FirstFlight.fromJson(raw == null ? null : jsonDecode(raw));
    } on FormatException {
      return FirstFlight();
    }
  }

  Future<({FirstFlight flight, String? message})> act(
    int revision,
    FlightAction action, [
    Object? value,
  ]) => learning.db.transaction(() async {
    final f = await read();
    if (f.revision != revision || f.complete) return (flight: f, message: null);
    final message = _apply(f, action, value);
    if (message != null) return (flight: f, message: message);
    if (action == FlightAction.teach) {
      await KnowledgeRepository(learning).encounter(
        KnowledgeCatalog.flight[value as FlightWord]!.skill,
        'first-flight:${f.room.name}',
      );
    }
    if (f.complete) {
      final inventory = Inventory.decode(
        await learning.setting(RewardsRepository.storageKey),
      );
      inventory.grants.putIfAbsent(
        FirstFlight.reward,
        () => const ChestGrant(FirstFlight.reward, 'explorer'),
      );
      await learning.setSetting(
        RewardsRepository.storageKey,
        inventory.encode(),
      );
    }
    f.revision++;
    await learning.setSetting(key, jsonEncode(f.toJson()));
    return (flight: f, message: null);
  });

  String? _apply(FirstFlight f, FlightAction action, Object? value) {
    final room = f.room;
    if (action == FlightAction.teach) {
      final next = FlightWord.deck(
        room,
      ).where((word) => !f.learned.contains(word)).firstOrNull;
      if (next == null || next != value) {
        return 'Орби сначала покажет предыдущую запись.';
      }
      f.learned.add(next);
      return null;
    }
    if (action != FlightAction.travel && !f.knowsRoom(room)) {
      return 'Сначала поговори с Орби. Он покажет, как устроен этот отсек.';
    }
    switch (action) {
      case FlightAction.travel:
        if (value == FlightRoom.airlock && room == FlightRoom.workshop ||
            value == FlightRoom.workshop &&
                (room == FlightRoom.airlock && f.unlocked ||
                    room == FlightRoom.bridge) ||
            value == FlightRoom.bridge &&
                room == FlightRoom.workshop &&
                f.powered) {
          f.room = value as FlightRoom;
          return null;
        }
        return 'Проход пока закрыт. Проверь цель отсека.';
      case FlightAction.take:
        switch ((room, value)) {
          case (FlightRoom.airlock, FlightItem.key):
          case (FlightRoom.workshop, FlightItem.battery) when !f.charged:
          case (FlightRoom.workshop, FlightItem.cable) when !f.wired:
          case (FlightRoom.bridge, FlightItem.reserve)
              when f.lockerOpen && !f.navigable:
            f.inventory.add(value as FlightItem);
            return null;
          default:
            return 'Здесь сейчас нечего взять.';
        }
      case FlightAction.unlock:
        if (room == FlightRoom.bridge && !f.reserveRequested) {
          return 'Попроси у Орби батарею для навигации. Он проверит, где лежит запасная.';
        }
        if (room != FlightRoom.airlock && room != FlightRoom.bridge) {
          return 'Здесь нет замка для ключа.';
        }
        if (value != FlightItem.key || !f.inventory.contains(FlightItem.key)) {
          return 'Замок открывается ключом. Выбери ключ в рюкзаке, затем коснись замка.';
        }
        f.milestones.add(room == FlightRoom.airlock ? 'unlocked' : 'locker');
      case FlightAction.fitBattery:
        if (room != FlightRoom.workshop ||
            value != FlightItem.battery ||
            !f.inventory.remove(FlightItem.battery)) {
          return 'Генератору нужна большая батарея. Выбери её в рюкзаке и коснись гнезда.';
        }
        f.milestones.add('charged');
      case FlightAction.fitCable:
        if (room != FlightRoom.workshop ||
            value != FlightItem.cable ||
            !f.inventory.remove(FlightItem.cable)) {
          return 'Два разъёма соединяются кабелем. Выбери кабель в рюкзаке и коснись разъёмов.';
        }
        f.milestones.add('wired');
      case FlightAction.turnA:
      case FlightAction.turnB:
        if (room != FlightRoom.workshop || f.powered) {
          return 'Переключатели больше не нужно поворачивать.';
        }
        if (action == FlightAction.turnA) {
          f.rotorA = (f.rotorA + 1) % 4;
        } else {
          f.rotorB = (f.rotorB + 1) % 4;
        }
      case FlightAction.breaker:
        if (room != FlightRoom.workshop) {
          return 'Выключатель питания в мастерской.';
        }
        if (!f.charged || !f.wired) {
          return 'Цепь разомкнута. Поставь батарею в гнездо и соедини разъёмы кабелем.';
        }
        if (f.rotorA != 0 || f.rotorB != 3) {
          return 'Цепь ещё разомкнута. Сверь направление стрелок с дорожкой на полу. Запитанная часть светится.';
        }
        f.milestones.add('powered');
      case FlightAction.requestReserve:
        if (room != FlightRoom.bridge) {
          return 'Запасная батарея нужна для пульта в рубке.';
        }
        f.milestones.add('requested');
      case FlightAction.fitReserve:
        if (room != FlightRoom.bridge ||
            value != FlightItem.reserve ||
            !f.inventory.remove(FlightItem.reserve)) {
          return 'В гнезде нет питания. Выбери маленькую батарею из шкафчика.';
        }
        f.milestones.add('navigable');
      case FlightAction.launch:
        if (room != FlightRoom.bridge || !f.navigable) {
          return 'Свет у пульта ещё не горит. Сначала подключи запасную батарею.';
        }
        f.milestones.add('complete');
      case FlightAction.teach:
        throw StateError('Teaching is handled before room actions');
    }
    return null;
  }
}
