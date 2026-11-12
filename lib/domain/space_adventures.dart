import 'dart:convert';

enum AdventureAction { inspect, dialogue, assemble, cargo, route }

/// Immutable authoring data. English, explanations and stable IDs are separate.
class AdventureStep {
  final String id, room, target, title, english, explanation, answer;
  final AdventureAction action;
  final List<String> options, words;
  const AdventureStep(
    this.id,
    this.room,
    this.target,
    this.title,
    this.english,
    this.explanation,
    this.action, {
    this.answer = '',
    this.options = const [],
    this.words = const [],
  });
  bool get assessed => action != AdventureAction.inspect;
}

class SpaceAdventure {
  final String id, title, subtitle, guide, outcome;
  final List<String> prerequisites, recap;
  final List<AdventureStep> steps;
  const SpaceAdventure(
    this.id,
    this.title,
    this.subtitle,
    this.guide,
    this.outcome,
    this.prerequisites,
    this.recap,
    this.steps,
  );
  bool unlocked(Set<String> lessons) => prerequisites.every(lessons.contains);
  int get xp => steps.where((s) => s.assessed).length * 10;
  void validate() {
    if (steps.isEmpty ||
        steps.map((s) => s.id).toSet().length != steps.length) {
      throw StateError('Invalid adventure steps: $id');
    }
    for (final step in steps) {
      if (step.explanation.isEmpty ||
          step.english.isEmpty ||
          (step.assessed && (step.answer.isEmpty || step.words.isEmpty)) ||
          (step.action != AdventureAction.assemble &&
              step.assessed &&
              !step.options.contains(step.answer))) {
        throw StateError('Invalid adventure instruction: $id/${step.id}');
      }
    }
  }

  static SpaceAdventure byId(String id) => all.firstWhere((a) => a.id == id);
  static const all = [
    SpaceAdventure(
      'beacon',
      'Сигнал с маяка',
      'Верни станции голос',
      'miko',
      'Маяк снова на связи. Мико услышал твоё приветствие!',
      ['a1-01'],
      [
        'Hello! — Привет!',
        'My name is Orbi. — Меня зовут Орби.',
        'Goodbye! — До свидания!',
      ],
      [
        AdventureStep(
          'guide',
          'deck',
          'guide',
          'Подойди к Мико',
          'Hello!',
          'Мико: «Привет! Маяк молчит. Найдём мой канал и отправим сообщение». Hello — привет; Goodbye — до свидания.',
          AdventureAction.inspect,
        ),
        AdventureStep(
          'hello',
          'deck',
          'guide',
          'Поздоровайся с Мико',
          'Hello!',
          'При встрече говорят Hello! Goodbye пригодится в конце разговора.',
          AdventureAction.dialogue,
          answer: 'Hello!',
          options: ['Goodbye!', 'Hello!'],
          words: ['en:hello'],
        ),
        AdventureStep(
          'log',
          'deck',
          'log',
          'Изучи журнал связи',
          'My name is Miko.',
          'В журнале: «Меня зовут Мико». My name is… сообщает имя. Канал подписан именем собеседника.',
          AdventureAction.inspect,
        ),
        AdventureStep(
          'channel',
          'radio',
          'console',
          'Настрой канал по журналу',
          'My name is Miko.',
          'Нужен Мико: найди на пульте имя Miko из записи в журнале.',
          AdventureAction.route,
          answer: 'Miko',
          options: ['Anna', 'Zig', 'Miko'],
          words: ['en:name'],
        ),
        AdventureStep(
          'identity',
          'radio',
          'console',
          'Собери сообщение для передатчика',
          'My name is Orbi.',
          'Ты управляешь Орби. Собери «Меня зовут Орби»: My → name → is → Orbi. Нажми плитки по порядку.',
          AdventureAction.assemble,
          answer: 'My name is Orbi',
          options: ['Orbi', 'is', 'My', 'name'],
          words: ['en:name'],
        ),
        AdventureStep(
          'bye',
          'radio',
          'guide',
          'Заверши связь',
          'Goodbye!',
          'Мико услышал тебя! В конце разговора говорим Goodbye — до свидания.',
          AdventureAction.dialogue,
          answer: 'Goodbye!',
          options: ['Hello!', 'Goodbye!'],
          words: ['en:goodbye'],
        ),
      ],
    ),
    SpaceAdventure(
      'kit',
      'Пропавший набор Мико',
      'Собери груз в мастерской',
      'zig_quartz',
      'Навигационный набор собран. Зиг запускает доставку Мико!',
      ['a1-01', 'a1-03'],
      ['book — книга', 'pen — ручка', 'bag — сумка'],
      [
        AdventureStep(
          'book',
          'workshop',
          'book',
          'Осмотри стол с книгой',
          'book',
          'Зиг: «Мико опять всё разбросал! Book — книга. Забирай её со стола в свой набор».',
          AdventureAction.inspect,
        ),
        AdventureStep(
          'pen',
          'workshop',
          'pen',
          'Найди ручку у инструментов',
          'pen',
          'Pen — ручка. Коснись инструмента на стенде: он пригодится Мико для записей.',
          AdventureAction.inspect,
        ),
        AdventureStep(
          'bag',
          'workshop',
          'bag',
          'Загляни в шкаф',
          'bag',
          'Bag — сумка. Теперь три вещи найдены. В грузовом отсеке сопоставь вещи и английские ярлыки.',
          AdventureAction.inspect,
        ),
        AdventureStep(
          'sort-book',
          'cargo',
          'bay',
          'Отправь книгу в грузовой отсек',
          'book',
          'Book — книга. Перетащи книгу на отсек с ярлыком book. Или выбери вещь и нажми «Положить в отсек».',
          AdventureAction.cargo,
          answer: 'book',
          options: ['pen', 'bag', 'book'],
          words: ['en:book'],
        ),
        AdventureStep(
          'sort-pen',
          'cargo',
          'bay',
          'Найди груз по ярлыку',
          'pen',
          'Pen — ручка. Доставь ручку, а не сумку. Ошибку всегда можно исправить.',
          AdventureAction.cargo,
          answer: 'pen',
          options: ['bag', 'pen', 'book'],
          words: ['en:pen'],
        ),
        AdventureStep(
          'sort-bag',
          'cargo',
          'bay',
          'Закрой последний грузовой отсек',
          'bag',
          'Bag — сумка. Отправь сумку вслед за книгой и ручкой.',
          AdventureAction.cargo,
          answer: 'bag',
          options: ['book', 'bag', 'pen'],
          words: ['en:bag'],
        ),
      ],
    ),
    SpaceAdventure(
      'port',
      'Стыковка на космопорте',
      'Проведи корабль к своему терминалу',
      'miko',
      'Корабль пришвартован. Книги доставлены точно по адресу!',
      ['a1-03', 'a1-05'],
      ['book — книга', 'one — один', 'two — два', 'five — пять'],
      [
        AdventureStep(
          'manifest',
          'arrival',
          'log',
          'Прочитай грузовой манифест',
          'book',
          'Мико: «Везём книги!» Book — книга, pen — ручка, bag — сумка. Указатели обозначают груз. Выбери путь для книг.',
          AdventureAction.inspect,
        ),
        AdventureStep(
          'cargo-route',
          'arrival',
          'junction',
          'Направь корабль по грузовому указателю',
          'book',
          'Корабль везёт книги. Ищи book на указателе. Поворот изменит маршрут корабля.',
          AdventureAction.route,
          answer: 'book',
          options: ['bag', 'book', 'pen'],
          words: ['en:book'],
        ),
        AdventureStep(
          'numbers',
          'terminal',
          'log',
          'Изучи схему терминалов',
          'two',
          'One — один, two — два, five — пять. Терминалы помечены цифрами 1, 2 и 5. Мико назначил терминал two.',
          AdventureAction.inspect,
        ),
        AdventureStep(
          'terminal',
          'terminal',
          'junction',
          'Прослушай номер и направь корабль',
          'two',
          'Two означает два. Нажми указатель 2. Если звук недоступен, слово two всегда видно на экране.',
          AdventureAction.route,
          answer: '2',
          options: ['5', '1', '2'],
          words: ['en:two'],
        ),
        AdventureStep(
          'dock',
          'terminal',
          'console',
          'Открой один шлюз для корабля',
          'one',
          'One — один. Для одного корабля нужен один открытый шлюз. Выбери 1 на пульте.',
          AdventureAction.route,
          answer: '1',
          options: ['2', '5', '1'],
          words: ['en:one'],
        ),
      ],
    ),
  ];
}

class AdventureState {
  int step, revision, attempts;
  double x, y;
  String room, focus, dialogue, selection;
  bool hint, completed;
  final Set<String> found, resolved;
  final Map<String, int> errors;
  final List<String> tiles;
  AdventureState({
    this.step = 0,
    this.revision = 0,
    this.attempts = 0,
    this.x = .5,
    this.y = .78,
    this.room = '',
    this.focus = '',
    this.dialogue = '',
    this.selection = '',
    this.hint = false,
    this.completed = false,
    Set<String>? found,
    Set<String>? resolved,
    Map<String, int>? errors,
    List<String>? tiles,
  }) : found = found ?? {},
       resolved = resolved ?? {},
       errors = errors ?? {},
       tiles = tiles ?? [];
  String encode() => jsonEncode({
    'version': 1,
    'step': step,
    'revision': revision,
    'attempts': attempts,
    'x': x,
    'y': y,
    'room': room,
    'focus': focus,
    'dialogue': dialogue,
    'selection': selection,
    'hint': hint,
    'completed': completed,
    'found': found.toList(),
    'resolved': resolved.toList(),
    'errors': errors,
    'tiles': tiles,
  });
  factory AdventureState.decode(String? raw) {
    if (raw == null) return AdventureState();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['version'] != 1) {
      throw StateError(
        'Нужна более новая версия KVESMOS. Сохранение не изменено.',
      );
    }
    return AdventureState(
      step: j['step'],
      revision: j['revision'],
      attempts: j['attempts'],
      x: (j['x'] as num).toDouble(),
      y: (j['y'] as num).toDouble(),
      room: j['room'],
      focus: j['focus'],
      dialogue: j['dialogue'],
      selection: j['selection'],
      hint: j['hint'],
      completed: j['completed'],
      found: Set<String>.from(j['found']),
      resolved: Set<String>.from(j['resolved']),
      errors: Map<String, int>.from(j['errors']),
      tiles: List<String>.from(j['tiles']),
    );
  }
}
