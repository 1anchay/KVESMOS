import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/course.dart';
import '../domain/progress.dart';
import 'design.dart';

/// UI reactions never award XP, change answers or write learning state.
class CharacterCue {
  final String id, name, emotion;
  final List<String> lines;
  const CharacterCue(this.id, this.name, this.lines, {this.emotion = 'happy'});

  static const greeting = CharacterCue('orbi', 'Орби', [
    'Привет! Проверим, какие открытия ждут нас сегодня?',
    'Кольцо на месте, звезда сияет. Можно отправляться за знаниями!',
  ], emotion: 'wink_thumbsup');
  static const correct = CharacterCue('orbi', 'Орби', [
    'Есть контакт! Ты поймал верный сигнал.',
    'Вот это точность! Ещё одна звёздочка знаний.',
  ]);
  static const support = CharacterCue('orbi', 'Орби', [
    'Ничего страшного. Разберём подсказку и попробуем ещё раз.',
    'Ошибка — полезный сигнал. Теперь мы знаем, что потренировать.',
  ], emotion: 'thinking');
  static const completed = CharacterCue('orbi', 'Орби', [
    'Урок пройден! Хорошая работа, исследователь.',
    'Эту орбиту мы освоили вместе. Дай себе минутку порадоваться!',
  ], emotion: 'wink_thumbsup');
  static const reward = CharacterCue('orbi', 'Орби', [
    'Ого, какая находка! Уже хочется примерить?',
    'Пополнение коллекции! Пикси отлично бережёт наши сокровища.',
  ], emotion: 'surprised');
  static const pixieReady = CharacterCue('pixie', 'Пикси', [
    'Сундук заработан! Посмотрим, что он приготовил?',
    'Все находки я бережно отправляю в твою коллекцию.',
  ]);
  static const pixieComplete = CharacterCue('pixie', 'Пикси', [
    'Все доступные находки этого сундука уже в коллекции. Сундук я сохраню!',
    'Загляни в коллекцию — можно выбрать новое сочетание оформления.',
  ]);
  static CharacterCue pixieReward(String rarity, {required bool fresh}) =>
      CharacterCue('pixie', 'Пикси', [
        fresh
            ? '$rarity предмет! Поздравляю с пополнением коллекции.'
            : '$rarity предмет. Вот твоя сохранённая находка!',
        'Можно заглянуть в коллекцию и выбрать оформление по настроению.',
      ]);
  static CharacterCue record(int xp) => CharacterCue('orbi', 'Орби', [
    'Новый дневной рекорд: $xp XP! Сегодня ты превзошёл свои прошлые дни.',
    'Вот это полёт! Сравнивай себя с собой — каждый шаг считается.',
  ], emotion: 'happy');
  static const navigator = CharacterCue('miko', 'Мико', [
    'Маршрут начинается с маленького шага. Я помогу сориентироваться!',
    'Выбери удобный старт. Большим открытиям спешка не нужна.',
  ]);
  static const words = CharacterCue('aster', 'Астэр', [
    'Слова складываются в созвездия. Найди знакомое и вспомни его смысл.',
    'У каждого слова свой сигнал. Произнеси его и представь, где оно пригодится.',
  ]);
  static const practice = CharacterCue('reyvo', 'Рэйво', [
    'Разомнём память! Одно знакомое слово за другим.',
    'Твой темп — лучший темп. Потренируем то, что уже встречали.',
  ]);
  static const engineer = CharacterCue('zig_quartz', 'Зиг Кварц', [
    'Проверим, какие детали подходят друг к другу. Настоящий эксперимент!',
    'Разделим задачу на маленькие части — так проще найти решение.',
  ]);
  static const detective = CharacterCue('vespa', 'Веспа', [
    'Смотри на улики в предложении. Одна деталь может подсказать решение.',
    'Не спеши с выводом. Перечитай фразу и проверь, что изменилось.',
  ]);
  static const keeper = CharacterCue('nox', 'Нокс', [
    'Прислушайся к сигналу. Иногда смысл скрывается в маленьком слове.',
    'Тишина помогает заметить детали. Фразу можно прослушать ещё раз.',
  ]);
  static const scholar = CharacterCue('fox_scholar', 'Профессор', [
    'Сравнивай дни, а не отдельные ошибки. Так лучше виден твой путь.',
    'Числа рассказывают историю практики. Маленькие занятия тоже оставляют след.',
  ]);
  static CharacterCue tutor(ExerciseType type) => switch (type) {
    ExerciseType.pairs || ExerciseType.gap => engineer,
    ExerciseType.correct || ExerciseType.dialogue => detective,
    ExerciseType.order => navigator,
    ExerciseType.listen || ExerciseType.speak => keeper,
    _ => words,
  };
}

/// A record needs a previous studying day, and must exceed it (not merely tie).
bool hasDailyXpRecord(ProgressSnapshot progress, DateTime localNow) {
  final today = dayKey(localNow);
  final previous = progress.dailyXp.entries.where(
    (e) => e.key.compareTo(today) < 0,
  );
  final best = previous.fold<int>(0, (v, e) => math.max(v, e.value));
  return best > 0 && (progress.dailyXp[today] ?? 0) > best;
}

/// Short, finite entrance and an optional second line on tap. No timers/loops.
class CharacterReaction extends StatefulWidget {
  final CharacterCue cue;
  final Object eventKey;
  final bool announce;
  const CharacterReaction({
    super.key,
    required this.cue,
    required this.eventKey,
    this.announce = true,
  });
  @override
  State<CharacterReaction> createState() => _CharacterReactionState();
}

class _CharacterReactionState extends State<CharacterReaction> {
  int line = 0;
  @override
  void didUpdateWidget(CharacterReaction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventKey != widget.eventKey ||
        oldWidget.cue.id != widget.cue.id) {
      line = 0;
    }
  }

  void nextLine() =>
      setState(() => line = (line + 1) % widget.cue.lines.length);
  @override
  Widget build(BuildContext context) {
    final cue = widget.cue;
    final text = cue.lines[line];
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      liveRegion: widget.announce,
      button: true,
      label: '${cue.name}. $text',
      hint: 'Ещё реплика',
      onTap: nextLine,
      excludeSemantics: true,
      child: Tooltip(
        message: 'Ещё реплика: ${cue.name}',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: nextLine,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey((widget.eventKey, cue.id, line)),
                  tween: Tween(begin: 0, end: 1),
                  duration: reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 420),
                  builder: (_, t, child) => Transform.translate(
                    offset: Offset(0, reduce ? 0 : 6 * (1 - t)),
                    child: Transform.rotate(
                      angle: reduce ? 0 : math.sin(math.pi * t) * .05,
                      child: child,
                    ),
                  ),
                  child: cue.id == 'orbi'
                      ? OrbitRobot(size: 70, emotion: cue.emotion)
                      : CharacterPortrait(cue.id, size: 70),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cue.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(text, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
