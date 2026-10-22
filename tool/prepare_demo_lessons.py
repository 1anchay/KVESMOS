"""Three authored A1 pilots. Original installed lessons are deliberately untouched."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets/courses/demo'
OUT.mkdir(parents=True, exist_ok=True)

def task(kind, prompt, answers, explanation, **extra):
    return dict(type=kind, prompt=prompt, answers=answers if isinstance(answers, list) else [answers], explanation=explanation, **extra)

lessons = [
    ('a1-01', 'Первый контакт · новая практика',
     'Hello — привет. My name is… — меня зовут… Goodbye — до свидания. С my name используем is. В диалоге можно ответить Hello или Hi.', [
        task('choice', 'Мико встречает тебя у станции. Как сказать «привет»?', 'Hello', 'Hello и Hi — приветствия. Goodbye используют при прощании.',
             options=['Hello', 'Goodbye', 'Name'], character='miko', introduction='Три сигнала: hello — привет, name — имя, goodbye — до свидания.'),
        task('order', 'Представься: «Меня зовут Мико».', 'My name is Miko', 'My name — моё имя. После него ставим is.', tokens=['My', 'name', 'is', 'Miko'], character='miko'),
        task('choice', 'Что говорит Орби?', 'Hello, Miko!', 'Сначала приветствие Hello, затем имя собеседника.', audio='Hello, Miko!', options=['Hello, Miko!', 'Goodbye, Miko!', 'My name is Orbi.']),
        task('pairs', 'Соедини три сигнала знакомства.', 'matched', 'Hello — привет, name — имя, goodbye — до свидания.', character='zig_quartz', usePairs=True),
        task('gap', 'My name ___ Orbi.', 'is', 'My name — единственное число, поэтому is.', options=['is', 'am', 'are'], character='aster'),
        task('dialogue', 'Как ответить при знакомстве?', ['Hello, Miko!', 'Hi, Miko!'], 'Hello и Hi — оба естественные приветствия.',
             scene='Мико: Hello! My name is Miko.\nТы встречаешь его впервые.', options=['Hello, Miko!', 'Hi, Miko!', 'Goodbye, Miko!'], character='miko', audio='Hello! My name is Miko.'),
        task('correct', 'Орби представился с ошибкой: I is Orbi. Помоги ему.', 'I am Orbi.', 'С I используем am: I am Orbi. Это ещё один способ представиться.', character='vespa', introduction='Ещё один способ назвать себя: I am Orbi. — Я Орби.'),
        task('choice', 'Гость уходит. Как попрощаться?', 'Goodbye!', 'Goodbye — до свидания. Hello подходит для начала встречи.', options=['Goodbye!', 'Hello!', 'My name is Miko.'], character='reyvo'),
        task('translate', 'Попрощайся с Мико: «Пока, Мико! До встречи!»', ['Bye, Miko! See you!', 'Goodbye, Miko! See you!'], 'Bye и Goodbye — прощание. See you! — До встречи!', character='orbi', introduction='Для дружеского прощания: See you! — До встречи!'),
        task('review', 'Быстрый сигнал памяти: напиши по-английски «до свидания».', ['goodbye', 'bye'], 'Goodbye, кратко bye. Повтори без спешки.', character='nox'),
     ]),
    ('a1-02', 'Новый друг на станции · новая практика',
     'From — из; friend — друг; welcome — добро пожаловать. I am from… — я из… В ответ на Where are you from? называют место, а не имя.', [
        task('choice', 'Астэр знакомит с новым словом. Что значит friend?', 'друг', 'Friend — друг; from — из; welcome — добро пожаловать.', options=['друг', 'из', 'добро пожаловать'], character='aster', introduction='Сегодня: from — из, friend — друг, welcome — добро пожаловать. England — Англия, Mars — Марс.'),
        task('order', 'Собери: «Я из Англии».', 'I am from England', 'I am from + место происхождения.', tokens=['I', 'am', 'from', 'England'], character='miko'),
        task('choice', 'Рэйво обращается к тебе. Что он делает?', 'Приветствует друга', 'Welcome, my friend! — Добро пожаловать, мой друг!', audio='Welcome, my friend!', options=['Приветствует друга', 'Прощается', 'Называет своё имя'], character='reyvo'),
        task('pairs', 'Соедини слова нового знакомства.', 'matched', 'From — из, friend — друг, welcome — добро пожаловать.', character='zig_quartz', usePairs=True),
        task('gap', 'Орби представляет спутника: This is my ___.', 'friend', 'This is my friend. — Это мой друг.', options=['friend', 'from', 'welcome'], character='fox_scholar', introduction='This is my friend. — Это мой друг.'),
        task('dialogue', 'Что ответить гостю?', 'I am from England.', 'Where are you from? — Откуда ты? Отвечаем I am from + место.',
             scene='Веспа: Where are you from?\nТы прибыл из Англии.', audio='Where are you from?', options=['I am from England.', 'My name is Miko.', 'Goodbye!'], character='vespa'),
        task('correct', 'Зиг записал: You is my friend. Найди ошибку.', 'You are my friend.', 'С You используем are: You are my friend. — Ты мой друг.', character='vespa', introduction='I am — я; You are — ты. You are my friend. — Ты мой друг.'),
        task('order', 'Собери разговор: сначала приветствие, затем знакомство, затем приглашение.', 'A: Hello! B: My name is Miko. A: Welcome, Miko!',
             'Приветствуем гостя, узнаём его имя и приглашаем на станцию.', tokens=['A: Hello!', 'B: My name is Miko.', 'A: Welcome, Miko!'], character='zig_quartz'),
        task('choice', 'Ты встречаешь нового гостя на станции. Выбери дружелюбную реплику.', 'Welcome!', 'Welcome! — Добро пожаловать! Подходит для встречи гостя.', options=['Welcome!', 'Goodbye!', 'I am from Mars.'], character='orbi'),
        task('review', 'Закрепим: переведи «друг».', 'friend', 'Friend — друг. Вспомни нового друга на станции.', character='reyvo'),
     ]),
    ('a1-03', 'Собираем сумку · новая практика',
     'Book — книга; pen — ручка; bag — сумка. This is a… — это… Перед одним предметом используем a. My — мой/моя. In the bag — в сумке.', [
        task('choice', 'Что изображено на карточке?', 'book', 'Book — книга. Pen — ручка, bag — сумка.', visual='book', options=['book', 'pen', 'bag'], character='aster', introduction='Собираемся в путь: book — книга, pen — ручка, bag — сумка. This is a… — это…'),
        task('order', 'Скажи: «Это ручка».', 'This is a pen', 'This is a + один предмет: This is a pen.', tokens=['This', 'is', 'a', 'pen'], character='miko'),
        task('choice', 'Какой предмет просит Нокс?', 'bag', 'My bag — моя сумка. В вопросе звучит bag.', audio='Where is my bag?', options=['book', 'pen', 'bag'], character='nox'),
        task('pairs', 'Проверь, что берём в путешествие.', 'matched', 'Book — книга, pen — ручка, bag — сумка.', character='zig_quartz', usePairs=True),
        task('gap', 'This is ___ book.', 'a', 'Перед одним исчисляемым предметом здесь нужен артикль a.', options=['a', 'am', 'are'], character='fox_scholar'),
        task('dialogue', 'Мико показывает книгу. Что ответить?', ['Yes, it is.', 'Yes.'], 'На Is this your book? можно ответить Yes, it is. Краткое Yes тоже естественно.', scene='Мико: Is this your book?\nДа, это твоя книга.', audio='Is this your book?', options=['Yes, it is.', 'Yes.', 'Goodbye!'], character='miko'),
        task('correct', 'Исправь: This are a bag.', 'This is a bag.', 'This указывает на один предмет, поэтому is.', character='vespa'),
        task('choice', 'Орби не видит ручку. Она лежит в сумке. Подскажи.', 'It is in the bag.', 'In the bag — в сумке. Отвечаем, где предмет.', scene='Орби: Where is my pen?', options=['It is in the bag.', 'My name is Miko.', 'Welcome!'], character='orbi', introduction='Полезная фраза: It is in the bag. — Она/он в сумке.'),
        task('translate', 'Это моя книга.', ['This is my book.', 'It is my book.'], 'My заменяет артикль a: my book.', character='aster'),
        task('review', 'Пикси проверяет сумку: как по-английски «ручка»?', 'pen', 'Pen — ручка. Теперь всё готово к путешествию!', visual='pen', character='pixie'),
     ]),
]
for lesson_id, title, guide, exercises in lessons:
    base = json.loads((ROOT / f'assets/courses/{lesson_id}.json').read_text(encoding='utf-8'))
    base.update(title=title, guide=guide, exercises=exercises)
    for index, exercise in enumerate(exercises):
        exercise['id'] = f'{lesson_id}-pilot1-e{index + 1:02}'
        exercise['phase'] = ['Знакомство'] * 2 + ['Понимание'] * 3 + ['Практика'] * 3 + ['Закрепление'] * 2
        exercise['phase'] = exercise['phase'][index]
        exercise['wordIds'] = [v['id'] for v in base['vocabulary']
          if v['en'].lower() in (' '.join(exercise['answers']) + ' ' + exercise.get('audio', '') + ' ' + exercise['prompt']).lower()]
        if exercise.pop('usePairs', False):
            exercise['pairs'] = base['vocabulary']
            exercise['wordIds'] = [v['id'] for v in base['vocabulary']]
    (OUT / f'{lesson_id}.json').write_text(json.dumps(base, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Saved three A1 pilots, 30 authored exercises; installed course assets unchanged.')
