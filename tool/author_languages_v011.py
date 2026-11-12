"""Original Russian-guided lessons. No translation of the legacy English JSON.

The shared exercise renderer is intentional; situations, grammar and lexical
progressions below are authored for each language. Run from repository root.
"""
import json
from pathlib import Path

# title, objective, grammar, four (expression, meaning) pairs, three words,
# gap (prompt, answer, distractors), dialogue (situation, response, distractors),
# correction (incorrect sentence, corrected sentence, explanation).
LESSONS = {
'en': [
('Время встречи', 'Договориться о времени и дне встречи.',
 'Для часов используем at: at two. Для дней — on: on Monday. What time is it? — который час? It is two — сейчас два.',
 [('What time is it?', 'Который час?'), ('It is two o’clock.', 'Сейчас два часа.'), ('Let’s meet on Monday.', 'Давай встретимся в понедельник.'), ('See you at two.', 'Увидимся в два.')],
 [('time','время'),('Monday','понедельник'),('two','два')],
 ('Увидимся в два: See you ___ two.', 'at', ['on','in']),
 ('Мико уточняет время встречи: «What time shall we meet?» Ответь: в два.', 'Let’s meet at two.', ['Let’s meet on Monday.','It is my house.']),
 ('See you on two.', 'See you at two.', 'Перед временем по часам нужен at; on используется с днями.')),
('Покупки и цена', 'Узнать цену и вежливо попросить покупку.',
 'How much is…? спрашивает цену одной вещи. I would like… — вежливое «я хотел бы…». Сумма во множественном числе: five pounds.',
 [('How much is this bag?', 'Сколько стоит эта сумка?'), ('It is five pounds.', 'Это стоит пять фунтов.'), ('I would like this bag, please.', 'Я хотел бы эту сумку, пожалуйста.'), ('Can I pay by card?', 'Можно заплатить картой?')],
 [('bag','сумка'),('pound','фунт'),('card','карта')],
 ('Одна сумка: How much ___ this bag?', 'is', ['are','am']),
 ('Продавец спрашивает «How would you like to pay?» Попроси оплатить картой.', 'Can I pay by card?', ['It is five pounds.','How much is this bag?']),
 ('It is five pound.', 'It is five pounds.', 'После five у исчисляемого pound добавляем -s.')),
('На автобусной остановке', 'Найти остановку и уточнить маршрут.',
 'Where is…? помогает найти место. Does this bus go to…? — вопрос о маршруте: после does используем go, без -s. A ticket to… — билет до…',
 [('Where is the bus stop?', 'Где автобусная остановка?'), ('Does this bus go to the station?', 'Этот автобус идёт до вокзала?'), ('One ticket to the station, please.', 'Один билет до вокзала, пожалуйста.'), ('Turn left at the station.', 'Поверните налево у вокзала.')],
 [('bus','автобус'),('station','вокзал'),('ticket','билет')],
 ('Уточни маршрут: Does this bus ___ to the station?', 'go', ['goes','going']),
 ('Ты у кассы. Кассир ждёт твой заказ. Попроси один билет до вокзала.', 'One ticket to the station, please.', ['Where is the bus stop?','Turn left at the station.']),
 ('Does this bus goes to the station?', 'Does this bus go to the station?', 'В вопросе с does основной глагол остаётся в форме go.')),
('У меня дома', 'Описать комнаты и расположение вещей.',
 'There is — есть один предмет; there are — несколько. In — внутри, on — на поверхности. В описании комнаты сначала называем вещь, затем место.',
 [('There is a table in the kitchen.', 'На кухне есть стол.'), ('There are two chairs.', 'Есть два стула.'), ('The book is on the table.', 'Книга на столе.'), ('This is my bedroom.', 'Это моя спальня.')],
 [('kitchen','кухня'),('chair','стул'),('bedroom','спальня')],
 ('Два стула: There ___ two chairs.', 'are', ['is','am']),
 ('Орби ищет книгу: «Where is the book?» Подскажи, что она на столе.', 'The book is on the table.', ['This is my bedroom.','There are two chairs.']),
 ('There is two chairs.', 'There are two chairs.', 'Two chairs — множественное число, поэтому there are.')),
('Погода и планы', 'Описать погоду и выбрать подходящий план.',
 'О погоде говорим с it: It is cold, It is sunny. It is raining — сейчас идёт дождь. В русском «холодно» без подлежащего, а в английском it обязательно.',
 [('It is sunny today.', 'Сегодня солнечно.'), ('It is cold outside.', 'На улице холодно.'), ('It is raining.', 'Идёт дождь.'), ('Let’s take an umbrella.', 'Давай возьмём зонт.')],
 [('sunny','солнечно'),('cold','холодно'),('umbrella','зонт')],
 ('Погода за окном: ___ is cold outside.', 'It', ['I','They']),
 ('Мико говорит: «It is raining.» Предложи взять зонт.', 'Let’s take an umbrella.', ['It is sunny today.','This is my bedroom.']),
 ('Is sunny today.', 'It is sunny today.', 'Для описания погоды в английском нужно подлежащее it.')),
('Свободное время', 'Рассказать об увлечении и пригласить друга.',
 'После enjoy используем глагол с -ing: enjoy reading. Play the guitar — играть на гитаре, но play football — играть в футбол, без the. Do you like…? — вопрос о предпочтении.',
 [('I enjoy reading.', 'Мне нравится читать.'), ('I play the guitar.', 'Я играю на гитаре.'), ('Do you like football?', 'Тебе нравится футбол?'), ('Let’s play together.', 'Давай поиграем вместе.')],
 [('reading','чтение'),('guitar','гитара'),('together','вместе')],
 ('Люблю читать: I enjoy ___.', 'reading', ['read','reads']),
 ('Друг говорит: «I like football.» Предложи поиграть вместе.', 'Let’s play together.', ['I play the guitar.','I enjoy reading.']),
 ('I play guitar.', 'I play the guitar.', 'В этом выражении с музыкальным инструментом нужен the.')),
('Как ты себя чувствуешь?', 'Сообщить о самочувствии и попросить воду.',
 'I feel… — я чувствую себя… I have a headache — у меня болит голова: перед headache нужен a. I need… — мне нужно… Здесь учимся общаться, а не ставить диагнозы.',
 [('How do you feel?', 'Как ты себя чувствуешь?'), ('I feel tired.', 'Я чувствую усталость.'), ('I have a headache.', 'У меня болит голова.'), ('I need some water, please.', 'Мне нужно немного воды, пожалуйста.')],
 [('tired','уставший'),('headache','головная боль'),('water','вода')],
 ('Болит голова: I have ___ headache.', 'a', ['an','two']),
 ('Орби спрашивает: «Can I help?» Вежливо попроси воды.', 'I need some water, please.', ['How do you feel?','I play the guitar.']),
 ('I have headache.', 'I have a headache.', 'В выражении have a headache существительное требует a.')),
('Эмоции и поддержка', 'Назвать чувство и поддержать собеседника.',
 'I am happy / worried — я рад / волнуюсь. I feel better — мне лучше. После be не нужен feel: I am worried. It is okay to… — нормально что-то делать.',
 [('I am happy to see you.', 'Я рад тебя видеть.'), ('I am a little worried.', 'Я немного волнуюсь.'), ('It is okay to make mistakes.', 'Ошибаться нормально.'), ('I feel better now.', 'Теперь мне лучше.')],
 [('happy','радостный'),('worried','взволнованный'),('better','лучше')],
 ('Я волнуюсь: I ___ a little worried.', 'am', ['have','do']),
 ('Мико переживает из-за ошибки. Какая фраза поддержит его?', 'It is okay to make mistakes.', ['I am happy to see you.','How much is this bag?']),
 ('I am feel better now.', 'I feel better now.', 'Feel уже является глаголом; am перед ним здесь не нужен.')),
],
'es': [
('Hola · первая встреча', 'Поздороваться, спросить о делах и попрощаться.',
 'Hola — привет; h не произносится. Buenos días — доброе утро или добрый день до обеда. Вопрос отмечается с двух сторон: ¿…? ¿Cómo estás? — как ты (неформально)?',
 [('Hola.', 'Привет.'), ('Buenos días.', 'Доброе утро.'), ('¿Cómo estás?', 'Как ты?'), ('Hasta luego.', 'До встречи.')],
 [('hola','привет'),('gracias','спасибо'),('bien','хорошо')],
 ('Спросим о делах одного друга: ¿Cómo ___?', 'estás', ['estoy','están']),
 ('Орби: «¿Cómo estás?» Ответь, что всё хорошо, и поблагодари.', 'Bien, gracias.', ['Hasta luego.','¿Cómo estás?']),
 ('¿Cómo estoy?', '¿Cómo estás?', 'Estoy — «я», estás — «ты». О делах друга спрашиваем ¿Cómo estás?')),
('Me llamo · знакомимся', 'Назвать имя и страну происхождения.',
 'Me llamo… — меня зовут…; ¿Cómo te llamas? — как тебя зовут? Soy de… — я из… Soy означает «я являюсь»: yo можно опустить. В испанском ll обычно звучит близко к «й», с региональными отличиями.',
 [('Me llamo Ana.', 'Меня зовут Ана.'), ('¿Cómo te llamas?', 'Как тебя зовут?'), ('Soy de Rusia.', 'Я из России.'), ('Mucho gusto.', 'Очень приятно.')],
 [('nombre','имя'),('Rusia','Россия'),('España','Испания')],
 ('Я из России: ___ de Rusia.', 'Soy', ['Es','Eres']),
 ('Мико: «Me llamo Miko.» Вежливо ответь, что тебе приятно познакомиться.', 'Mucho gusto.', ['Hasta luego.','¿Cómo estás?']),
 ('Me llamas Ana.', 'Me llamo Ana.', 'Говоря о себе, используем me llamo; te llamas — о собеседнике.')),
('Вещи вокруг · el и la', 'Назвать предметы и различить род артикля.',
 'Учите существительное вместе с артиклем: el libro — книга, la mesa — стол, la casa — дом. Род испанского слова может отличаться от русского. Un/una — один или неопределённый предмет. Es — «это есть».',
 [('Es un libro.', 'Это книга.'), ('Es una mesa.', 'Это стол.'), ('La casa es grande.', 'Дом большой.'), ('¿Qué es esto?', 'Что это?')],
 [('el libro','книга'),('la mesa','стол'),('la casa','дом')],
 ('Mesa женского рода: Es ___ mesa.', 'una', ['un','el']),
 ('Орби показывает книгу и спрашивает «¿Qué es esto?» Назови предмет.', 'Es un libro.', ['Es una mesa.','La casa es grande.']),
 ('Es una libro.', 'Es un libro.', 'Libro — мужского рода: el libro, un libro. Не переносим род русского «книга».')),
('Считаем и называем возраст', 'Посчитать до пяти и назвать возраст.',
 'Uno, dos, tres, cuatro, cinco — один, два, три, четыре, пять. Перед мужским существительным uno сокращается до un: un libro. Возраст выражается через tener: Tengo… años — мне… лет.',
 [('Tengo dos libros.', 'У меня две книги.'), ('Hay tres mesas.', 'Есть три стола.'), ('Tengo veinte años.', 'Мне двадцать лет.'), ('¿Cuántos años tienes?', 'Сколько тебе лет?')],
 [('dos','два'),('tres','три'),('cinco','пять')],
 ('Мне двадцать лет: ___ veinte años.', 'Tengo', ['Soy','Estoy']),
 ('Друг: «¿Cuántos años tienes?» Назови возраст — двадцать лет.', 'Tengo veinte años.', ['Tengo dos libros.','Hay tres mesas.']),
 ('Soy veinte años.', 'Tengo veinte años.', 'По-испански возраст «имеют»: tengo… años, а не soy.')),
('Моя семья', 'Представить близких и сказать, как их зовут.',
 'Mi — мой или моя перед одним предметом: mi madre, mi padre. Mis — перед несколькими: mis hermanos. Se llama… — его/её зовут… Hermano — брат, hermana — сестра.',
 [('Esta es mi madre.', 'Это моя мама.'), ('Este es mi padre.', 'Это мой папа.'), ('Mi hermana se llama Ana.', 'Мою сестру зовут Ана.'), ('Tengo dos hermanos.', 'У меня два брата.')],
 [('madre','мама'),('padre','папа'),('hermana','сестра')],
 ('Как зовут сестру: Mi hermana ___ llama Ana.', 'se', ['me','te']),
 ('Орби: «¿Cómo se llama tu hermana?» Скажи, что её зовут Ана.', 'Se llama Ana.', ['Me llamo Miko.','Este es mi padre.']),
 ('Esta es mis madre.', 'Esta es mi madre.', 'Madre — один человек, поэтому mi; mis нужно перед множественным числом.')),
('В кафе · еда и заказ', 'Вежливо заказать еду и попросить счёт.',
 'Quisiera… — я хотел(а) бы… Por favor — пожалуйста, gracias — спасибо. Un café — один кофе, una sopa — один суп. La cuenta — счёт. Слово agua женского рода, но здесь используем его без артикля: agua, por favor.',
 [('Quisiera un café, por favor.', 'Я хотел бы кофе, пожалуйста.'), ('Una sopa, por favor.', 'Суп, пожалуйста.'), ('Agua, por favor.', 'Воды, пожалуйста.'), ('La cuenta, por favor.', 'Счёт, пожалуйста.')],
 [('café','кофе'),('sopa','суп'),('agua','вода')],
 ('Sopa женского рода: ___ sopa, por favor.', 'Una', ['Un','Uno']),
 ('Ты закончил обед и хочешь оплатить заказ. Что скажешь официанту?', 'La cuenta, por favor.', ['Una sopa, por favor.','Buenos días.']),
 ('Un sopa, por favor.', 'Una sopa, por favor.', 'Существительное sopa женского рода, поэтому una.')),
],
'de': [
('Hallo · приветствие', 'Поздороваться и спросить о делах.',
 'Hallo — привет. Guten Morgen — доброе утро. Wie geht es dir? — как твои дела? (неформально). Danke, gut — спасибо, хорошо. В немецком все существительные пишутся с заглавной буквы: Morgen.',
 [('Hallo.', 'Привет.'), ('Guten Morgen.', 'Доброе утро.'), ('Wie geht es dir?', 'Как твои дела?'), ('Auf Wiedersehen.', 'До свидания.')],
 [('hallo','привет'),('danke','спасибо'),('gut','хорошо')],
 ('Вежливое утреннее приветствие: Guten ___.', 'Morgen', ['danke','gut']),
 ('Орби: «Wie geht es dir?» Ответь, что всё хорошо, и поблагодари.', 'Danke, gut.', ['Auf Wiedersehen.','Wie geht es dir?']),
 ('Gute Morgen.', 'Guten Morgen.', 'Устойчивое утреннее приветствие — Guten Morgen; окончание -en нужно сохранить.')),
('Ich heiße · имя и происхождение', 'Представиться и назвать свою страну.',
 'Ich heiße… — меня зовут…; ß читается как «с». Wie heißt du? — как тебя зовут? Ich komme aus… — я из… Глагол в обычном предложении стоит на втором месте: Ich komme aus Russland.',
 [('Ich heiße Anna.', 'Меня зовут Анна.'), ('Wie heißt du?', 'Как тебя зовут?'), ('Ich komme aus Russland.', 'Я из России.'), ('Freut mich.', 'Очень приятно.')],
 [('Name','имя'),('Russland','Россия'),('Deutschland','Германия')],
 ('Я представляюсь: Ich ___ Anna.', 'heiße', ['heißt','heißen']),
 ('Мико: «Woher kommst du?» Ответь, что ты из России.', 'Ich komme aus Russland.', ['Ich heiße Anna.','Freut mich.']),
 ('Ich aus Russland komme.', 'Ich komme aus Russland.', 'В повествовательной фразе спрягаемый глагол komme занимает второе место.')),
('Предметы · der, die, das', 'Назвать предмет с правильным артиклем.',
 'В немецком три рода: der Tisch — стол, die Lampe — лампа, das Buch — книга. Запоминайте слово с артиклем. Ein используется с мужским и средним родом, eine — с женским. Существительные пишутся с заглавной буквы.',
 [('Das ist ein Buch.', 'Это книга.'), ('Das ist eine Lampe.', 'Это лампа.'), ('Der Tisch ist groß.', 'Стол большой.'), ('Was ist das?', 'Что это?')],
 [('der Tisch','стол'),('die Lampe','лампа'),('das Buch','книга')],
 ('Lampe женского рода: Das ist ___ Lampe.', 'eine', ['ein','einen']),
 ('Орби показывает книгу: «Was ist das?» Ответь, что это книга.', 'Das ist ein Buch.', ['Das ist eine Lampe.','Der Tisch ist groß.']),
 ('Das ist eine Buch.', 'Das ist ein Buch.', 'Buch среднего рода: das Buch, ein Buch. Род русского слова здесь не помогает.')),
('Числа и возраст', 'Посчитать предметы и назвать возраст.',
 'Eins, zwei, drei, vier, fünf — один, два, три, четыре, пять. Перед Buch: ein Buch. Возраст выражаем с sein: Ich bin… Jahre alt. В zwei Bücher меняются гласная и окончание слова Buch.',
 [('Ich habe zwei Bücher.', 'У меня две книги.'), ('Hier sind drei Lampen.', 'Здесь три лампы.'), ('Ich bin zwanzig Jahre alt.', 'Мне двадцать лет.'), ('Wie alt bist du?', 'Сколько тебе лет?')],
 [('zwei','два'),('drei','три'),('fünf','пять')],
 ('Мне двадцать лет: Ich ___ zwanzig Jahre alt.', 'bin', ['habe','bist']),
 ('Друг: «Wie alt bist du?» Назови возраст — двадцать лет.', 'Ich bin zwanzig Jahre alt.', ['Ich habe zwei Bücher.','Hier sind drei Lampen.']),
 ('Ich habe zwanzig Jahre alt.', 'Ich bin zwanzig Jahre alt.', 'Для возраста используем bin… Jahre alt, а не habe.')),
('Моя семья', 'Представить семью и назвать имя близкого.',
 'Mein Vater — мой папа, meine Mutter — моя мама. Окончание зависит от рода слова. Sie heißt… — её зовут…; er heißt… — его зовут… Schwester — сестра, Bruder — брат.',
 [('Das ist meine Mutter.', 'Это моя мама.'), ('Das ist mein Vater.', 'Это мой папа.'), ('Meine Schwester heißt Anna.', 'Мою сестру зовут Анна.'), ('Mein Bruder heißt Max.', 'Моего брата зовут Макс.')],
 [('Mutter','мама'),('Vater','папа'),('Schwester','сестра')],
 ('Mutter женского рода: Das ist ___ Mutter.', 'meine', ['mein','meinen']),
 ('Орби: «Wie heißt deine Schwester?» Ответь, что её зовут Анна.', 'Sie heißt Anna.', ['Er heißt Max.','Ich heiße Miko.']),
 ('Das ist mein Mutter.', 'Das ist meine Mutter.', 'С существительным женского рода Mutter используется meine.')),
('В кафе · вежливый заказ', 'Заказать напиток и попросить счёт.',
 'Ich möchte… — я хотел(а) бы… После möchte предмет — дополнение: der Kaffee превращается в einen Kaffee. Das Wasser остаётся без артикля в заказе. Bitte — пожалуйста. Zahlen, bitte — счёт, пожалуйста (буквально: оплатить).',
 [('Ich möchte einen Kaffee, bitte.', 'Я хотел бы кофе, пожалуйста.'), ('Wasser, bitte.', 'Воды, пожалуйста.'), ('Eine Suppe, bitte.', 'Суп, пожалуйста.'), ('Zahlen, bitte.', 'Счёт, пожалуйста.')],
 [('Kaffee','кофе'),('Wasser','вода'),('Suppe','суп')],
 ('Закажем кофе: Ich möchte ___ Kaffee.', 'einen', ['ein','eine']),
 ('Ты закончил обед. Как попросить оплатить заказ?', 'Zahlen, bitte.', ['Eine Suppe, bitte.','Guten Morgen.']),
 ('Ich möchte ein Kaffee.', 'Ich möchte einen Kaffee.', 'Kaffee мужского рода; прямое дополнение после möchte требует einen.')),
]}

def write(path, data):
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf8')

known_words = {}
for old in sorted(Path('assets/courses').glob('a1-*.json')):
    for w in json.loads(old.read_text(encoding='utf8'))['vocabulary']:
        known_words[('en', w['en'].lower())] = w['id']

for language, lessons in LESSONS.items():
    entries = []
    for index, (title, objective, grammar, phrases, words, gap, dialogue, correction) in enumerate(lessons):
        number = index + (21 if language == 'en' else 1)
        lesson_id = f'{language}-a1-{number:02}'
        order = number - 1
        vocab = [dict(id=known_words.setdefault((language,w.lower()), f'{language}:'+w.lower().replace(' ','_')), en=w, ru=r) for w,r in words]
        ids = [w['id'] for w in vocab]
        exercises = []
        def ex(kind, prompt, answer, explanation, **kw):
            if 'options' in kw: kw['options'] = list(dict.fromkeys(kw['options']))
            exercises.append(dict(id=f'{lesson_id}-e{len(exercises)+1:02}', type=kind, prompt=prompt,
                answers=[answer], explanation=explanation, hint=explanation, wordIds=ids,
                phase=['Понимание','Практика','Закрепление'][min(len(exercises)//4,2)],
                character=['orbi','miko','zig_quartz'][len(exercises)%3], **kw))
        a,b,c,d=phrases
        ex('choice', f'Выбери фразу: «{a[1]}»', a[0], f'{a[0]} — {a[1]}', options=[b[0],a[0],d[0]])
        ex('choice', f'Что означает «{b[0]}»?', b[1], f'{b[0]} — {b[1]}', options=[c[1],d[1],b[1]])
        # Remove terminal punctuation only; preserve Spanish opening marks and umlauts.
        answer=c[0].rstrip('.!?')
        ex('order', f'Собери фразу: «{c[1]}»', answer, f'{c[0]} — {c[1]}', tokens=answer.split())
        ex('pairs','Соедини слова с их значениями.', 'matched', '; '.join(f'{w} — {r}' for w,r in words), pairs=vocab)
        ex('listen','Послушай и выбери значение. Если голос недоступен, прочитай фразу.',d[1],f'{d[0]} — {d[1]}', audio=d[0],options=[a[1],d[1],c[1]])
        ex('gap',gap[0],gap[1],grammar, options=[gap[2][0],gap[1],gap[2][1]])
        ex('dialogue',dialogue[0],dialogue[1],f'В этой ситуации подходит: {dialogue[1]}',options=[dialogue[2][0],dialogue[2][1],dialogue[1]], scene='cafe' if index==5 else 'meeting')
        # Case distinctions must be assessed as choices, since text grading is case-insensitive.
        ex('choice' if language=='de' and index==0 else 'correct',f'Выбери правильную фразу вместо «{correction[0]}».' if language=='de' and index==0 else f'Исправь фразу: «{correction[0]}»',correction[1],correction[2], **({'options':[correction[0],correction[1],b[0]]} if language=='de' and index==0 else {}))
        ex('translate',f'Вспомни без вариантов: «{d[1]}»',d[0],f'{d[0]} — {d[1]}')
        ex('review',f'Финал: {dialogue[0]}',dialogue[1],f'Теперь ты умеешь: {objective.lower()}', options=[dialogue[1],dialogue[2][1],dialogue[2][0]])
        material=dict(id=lesson_id,title=title,topic=title,order=order,objective=objective,guide=grammar,
            vocabulary=vocab,exercises=exercises,teachingSteps=[dict(character=['orbi','miko','zig_quartz','orbi'][i],
                title=['Первая фраза','Ответ собеседнику','Как устроен язык','Теперь попробуем'][i],
                phrase=p,translation=r,explanation=grammar if i==2 else f'Ситуация: {objective} {p} — {r}') for i,(p,r) in enumerate(phrases)])
        asset=f'assets/courses/{lesson_id}.json';write(asset,material)
        entries.append(dict(id=lesson_id,title=title,asset=asset,order=order))
    section=dict(id=f'{language}-v011',title='Жизненные ситуации' if language=='en' else 'Первые разговоры',themes=[dict(id=f'{language}-intro',title='Начальный курс',lessons=entries)])
    if language=='en':
        path='assets/courses/manifest.json';manifest=json.loads(Path(path).read_text(encoding='utf8'))
        manifest['sections']=[s for s in manifest['sections'] if s['id']!='en-v011']+[section]
        manifest['version']=2
    else:
        path=f'assets/courses/manifest-{language}.json';manifest=dict(id=f'ru-{language}',version=1,sourceLanguage='ru',targetLanguage=language,sections=[section])
    write(path,manifest)
print('Authored 8 English, 6 Spanish and 6 German lessons; preserved all legacy lesson files.')
