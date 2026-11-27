enum FlightRoom {
  airlock('Шлюз'),
  workshop('Мастерская'),
  bridge('Рубка');

  const FlightRoom(this.title);
  final String title;
}

enum FlightItem {
  key('Ключ', 'Key'),
  battery('Батарея', 'Battery'),
  cable('Кабель', 'Cable'),
  reserve('Запасная батарея', 'Battery');

  const FlightItem(this.title, this.english);
  final String title, english;
}

enum FlightWord {
  door('Door', 'дверь', 'Через эту дверь можно попасть в мастерскую.'),
  key('Key', 'ключ', 'Ключ открывает замки. Один лежит в аварийном ящике.'),
  battery('Battery', 'батарея', 'Заряженная батарея даст генератору питание.'),
  cable('Cable', 'кабель', 'Кабель соединит генератор с двумя разъёмами.'),
  light(
    'Light',
    'свет',
    'Свет у пульта покажет, что навигация получила питание.',
  ),
  button('Button', 'кнопка', 'Кнопкой у пульта мы запустим навигацию.'),
  need(
    'I need a battery.',
    'Мне нужна батарея.',
    'Так можно попросить у меня запасную батарею для пульта.',
  ),
  press(
    'Press the button.',
    'Нажми на кнопку.',
    'Я скажу это, когда загорится свет у пульта.',
  );

  const FlightWord(this.english, this.translation, this.context);
  final String english, translation, context;

  static List<FlightWord> deck(FlightRoom room) => switch (room) {
    FlightRoom.airlock => [door, key],
    FlightRoom.workshop => [battery, cable],
    FlightRoom.bridge => [light, button, need, press],
  };
}

enum FlightAction {
  teach,
  take,
  travel,
  unlock,
  fitBattery,
  fitCable,
  turnA,
  turnB,
  breaker,
  requestReserve,
  fitReserve,
  launch,
}

class FirstFlight {
  static const reward = 'first-flight:v1:patch';

  int revision = 0;
  FlightRoom room = FlightRoom.airlock;
  final learned = <FlightWord>{};
  final inventory = <FlightItem>{};
  final milestones = <String>{};
  int rotorA = 1, rotorB = 2;

  bool get unlocked => milestones.contains('unlocked');
  bool get charged => milestones.contains('charged');
  bool get wired => milestones.contains('wired');
  bool get powered => milestones.contains('powered');
  bool get reserveRequested => milestones.contains('requested');
  bool get lockerOpen => milestones.contains('locker');
  bool get navigable => milestones.contains('navigable');
  bool get complete => milestones.contains('complete');
  bool knowsRoom(FlightRoom room) => learned.containsAll(FlightWord.deck(room));

  String get objective {
    if (complete) return 'Корабль готов к полёту';
    if (!knowsRoom(room)) return 'Поговори с Орби';
    return switch (room) {
      FlightRoom.airlock =>
        unlocked ? 'Проверь питание в мастерской' : 'Открой дверь в мастерскую',
      FlightRoom.workshop =>
        powered ? 'Поднимись в рубку' : 'Восстанови питание корабля',
      FlightRoom.bridge =>
        navigable
            ? 'Запусти навигацию'
            : 'Подай питание на навигационный пульт',
    };
  }

  Map<String, Object> toJson() => {
    'revision': revision,
    'room': room.name,
    'learned': learned.map((word) => word.name).toList(),
    'inventory': inventory.map((item) => item.name).toList(),
    'milestones': milestones.toList(),
    'a': rotorA,
    'b': rotorB,
  };

  factory FirstFlight.fromJson(Object? value) {
    final flight = FirstFlight();
    if (value is! Map) return flight;
    Iterable<Object?> list(String key) =>
        value[key] is List ? (value[key] as List).cast<Object?>() : const [];
    return flight
      ..revision = value['revision'] is int ? value['revision'] as int : 0
      ..room =
          FlightRoom.values
              .where((room) => room.name == value['room'])
              .firstOrNull ??
          FlightRoom.airlock
      ..learned.addAll(
        FlightWord.values.where((word) => list('learned').contains(word.name)),
      )
      ..inventory.addAll(
        FlightItem.values.where(
          (item) => list('inventory').contains(item.name),
        ),
      )
      ..milestones.addAll(list('milestones').whereType<String>())
      ..rotorA = value['a'] is int ? (value['a'] as int) % 4 : 1
      ..rotorB = value['b'] is int ? (value['b'] as int) % 4 : 2;
  }

  FirstFlight();
}
