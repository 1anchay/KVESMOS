import 'course.dart';
import 'progress.dart';

/// A view over the existing course. IDs, access rules and scoring stay intact.
class JourneyRegion {
  final int index;
  final String title, subtitle, guide, invitation;
  const JourneyRegion(
    this.index,
    this.title,
    this.subtitle,
    this.guide,
    this.invitation,
  );
  static const all = [
    JourneyRegion(
      0,
      'Маяк знакомств',
      'Знакомиться и замечать мир',
      'orbi',
      'Поймаем первый сигнал. Я рядом!',
    ),
    JourneyRegion(
      1,
      'Обитаемые кольца',
      'Числа, семья и близкие',
      'zig_quartz',
      'Проверим координаты. Каждый ответ — точнее!',
    ),
    JourneyRegion(
      2,
      'Сад открытий',
      'Еда, цвета и вещи',
      'miko',
      'Соберём слова, которые пригодятся каждый день.',
    ),
    JourneyRegion(
      3,
      'Город движения',
      'День, занятия и увлечения',
      'zig_quartz',
      'Запускаем станцию: расскажи, как проходит твой день.',
    ),
    JourneyRegion(
      4,
      'Порт разговоров',
      'Маршруты и самостоятельный диалог',
      'miko',
      'Пора в путешествие. Ты уже многое умеешь!',
    ),
  ];
  static List<JourneyRegion> forCourse(String language) => language == 'en'
      ? [
          ...all,
          const JourneyRegion(
            5,
            'Орбита повседневности',
            'Время, покупки, транспорт и дом',
            'orbi',
            'Новые слова для реальных ситуаций.',
          ),
          const JourneyRegion(
            6,
            'Планета заботы',
            'Погода, хобби, самочувствие и эмоции',
            'miko',
            'Учимся говорить о том, что важно.',
          ),
        ]
      : [
          const JourneyRegion(
            0,
            'Первые разговоры',
            'Знакомство, предметы и числа',
            'orbi',
            'Начнём с понятных выражений.',
          ),
          const JourneyRegion(
            1,
            'Близкие и встречи',
            'Семья и заказ в кафе',
            'miko',
            'Применим слова в разговоре.',
          ),
        ];
  Iterable<LessonInfo> lessons(List<LessonInfo> catalog) =>
      catalog.skip(index * 4).take(4);
  bool complete(Set<String> done, List<LessonInfo> catalog) =>
      lessons(catalog).isNotEmpty &&
      lessons(catalog).every((l) => done.contains(l.id));
  static JourneyRegion forOrder(int order, {String language = 'en'}) {
    final regions = forCourse(language);
    return regions[(order ~/ 4).clamp(0, regions.length - 1)];
  }
}

class PracticePick {
  final Vocabulary word;
  final String reason;
  const PracticePick(this.word, this.reason);
}

/// Explainable selection, using existing SM-2 state rather than a second model.
List<PracticePick> personalPractice(
  Iterable<Vocabulary> vocabulary,
  ProgressSnapshot p,
  DateTime now, {
  int limit = 3,
}) {
  final selected = vocabulary.where((w) {
    final s = p.words[w.id];
    return s != null &&
        s.next != null &&
        (!s.next!.isAfter(now.toUtc()) || s.errors > 0 && s.repetitions == 0);
  }).toList();
  selected.sort((a, b) {
    final x = p.words[a.id]!, y = p.words[b.id]!;
    final weak = (y.repetitions == 0 ? y.errors : 0).compareTo(
      x.repetitions == 0 ? x.errors : 0,
    );
    if (weak != 0) return weak;
    final date = x.next!.compareTo(y.next!);
    return date != 0 ? date : a.id.compareTo(b.id);
  });
  return selected.take(limit).map((w) {
    final s = p.words[w.id]!;
    return PracticePick(
      w,
      s.repetitions == 0 && s.errors > 0
          ? 'Это слово вызывало трудности: ошибок ${s.errors}. Вспомним его в три шага.'
          : 'Пришло время повторения по твоему расписанию SM-2.',
    );
  }).toList();
}

class Expedition {
  final String id, title, detail, chest;
  final int count, target;
  const Expedition(
    this.id,
    this.title,
    this.detail,
    this.chest,
    this.count,
    this.target,
  );
  bool get complete => count >= target;

  /// Reconcile closed periods too: a crash on Sunday must not lose the reward
  /// when the app is next opened on Monday. One checkpoint per week/month.
  static Iterable<Expedition> earnedHistory(
    List<LearningEvent> events,
    DateTime now,
    String since,
  ) {
    if (dayKey(now).compareTo(since) < 0) return const [];
    final checkpoints = <String, DateTime>{'today': now};
    for (final e in events) {
      if (e.day.compareTo(since) < 0 || e.day.compareTo(dayKey(now)) > 0) {
        continue;
      }
      final date = DateTime.tryParse(e.day);
      if (date == null) continue;
      for (final period in [
        'w:${dayKey(date.subtract(Duration(days: date.weekday - 1)))}',
        'm:${e.day.substring(0, 7)}',
      ]) {
        if (!checkpoints.containsKey(period) ||
            date.isAfter(checkpoints[period]!)) {
          checkpoints[period] = date;
        }
      }
    }
    final earned = <String, Expedition>{};
    for (final date in checkpoints.values) {
      for (final e in fromEvents(events, date)) {
        if (e.complete) earned[e.id] = e;
      }
    }
    return earned.values;
  }

  static List<Expedition> fromEvents(
    Iterable<LearningEvent> source,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final week = dayKey(today.subtract(Duration(days: today.weekday - 1)));
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final end = dayKey(now);
    final days = <String>{}, lessons = <String>{};
    for (final e in {for (final e in source) e.id: e}.values) {
      if (e.day.compareTo(end) > 0) continue;
      if (e.day.compareTo(week) >= 0 &&
          e.kind == 'answer' &&
          e.data['correct'] == true) {
        days.add(e.day);
      }
      if (e.day.startsWith(month) && e.kind == 'complete') {
        lessons.add(e.data['lesson'] as String);
      }
    }
    return [
      Expedition(
        'expedition:v1:week:$week',
        'Три встречи с галактикой',
        'Учись в любые 3 дня этой недели. Подряд не обязательно.',
        'explorer',
        days.length,
        3,
      ),
      Expedition(
        'expedition:v1:month:$month',
        'Большое путешествие',
        'Заверши 8 разных уроков в этом месяце. Учитываются уже пройденные в этом месяце.',
        'nebula',
        lessons.length,
        8,
      ),
    ];
  }
}
