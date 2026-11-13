import 'course.dart';

// These rules are tied to the exact teaching prompt and answer. A different
// pinned revision or a different error uses the exercise's authored feedback.
const _contrast = <String, (String, String, String)>{
  'en-a1-61-e06': (
    'This jacket are too small.',
    'This jacket is too small.',
    'This jacket обозначает одну куртку, поэтому здесь is. С несколькими куртками было бы These jackets are too small.',
  ),
  'es-a1-07-e06': (
    'Soy en casa.',
    'Estoy en casa.',
    'En casa указывает, где человек находится. Для местоположения здесь нужно estar: estoy en casa. Soy подходит, например, в Soy profesora — «я учительница».',
  ),
  'de-a1-08-e06': (
    'Ich brauche ein Stift.',
    'Ich brauche einen Stift.',
    'Der Stift — мужской род. После brauche предмет стоит в Akkusativ: ein Stift → einen Stift. У среднего рода, например ein Buch, форма остаётся ein.',
  ),
  'fr-a1-14-e05': (
    'Je ne ai pas de voiture.',
    "Je n'ai pas de voiture.",
    'Ai начинается с гласной: ne сокращается до n’. Отрицание обрамляет глагол: n’ai pas. Перед согласной сокращения нет, например ne travaille pas.',
  ),
  'zh-a1-17-e06': (
    '我想买两书。',
    '我想买两本书。',
    'Между числом 两 (liǎng) и существительным 书 (shū) нужно счётное слово 本 (běn). 两本书 (liǎng běn shū) — две книги.',
  ),
  'zh-a1-21-e06': (
    '这衣服件太小了。',
    '这件衣服太小了。',
    'В сочетании 这件衣服 (zhè jiàn yīfu) порядок такой: указатель 这, счётное слово 件, предмет 衣服. 件 нельзя переносить после существительного.',
  ),
};

String mistakeExplanation(Exercise exercise, String input) {
  final rule = _contrast[exercise.id];
  if (rule != null &&
      normalizeAnswer(input) == normalizeAnswer(rule.$1) &&
      checkAnswer(exercise, rule.$2)) {
    return rule.$3;
  }
  return exercise.explanation;
}
