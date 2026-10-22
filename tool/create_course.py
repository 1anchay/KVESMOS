"""Authoring source for the original OrbitWords A1 course. No network required."""
import json
import re
from pathlib import Path

# topic, title, EN, RU, gap, missing, erroneous, explanation, dialogue, reply, vocabulary
LESSONS = [
('Приветствие и знакомство','Первый контакт','Hello, my name is Anna.','Привет, меня зовут Анна.','My name ___ Anna.','is','My name are Anna.','С единственным числом my name используется is.','Hello! What is your name?','My name is Anna.', [('hello','привет'),('name','имя'),('goodbye','до свидания')]),
('Приветствие и знакомство','Рад знакомству','I am from Russia.','Я из России.','I ___ from Russia.','am','I is from Russia.','С местоимением I используется am.','Where are you from?','I am from Russia.', [('from','из'),('friend','друг'),('welcome','добро пожаловать')]),
('Простые слова','Вокруг нас','This is a book.','Это книга.','This is ___ book.','a','This are a book.','This is означает «это». Перед исчисляемым существительным в единственном числе нужен артикль.','What is this?','It is a book.', [('book','книга'),('pen','ручка'),('bag','сумка')]),
('Простые слова','Здесь и там','That is my house.','То — мой дом.','That is ___ house.','my','That are my house.','That is указывает на один предмет вдали. My — притяжательное определение «мой».','Is that your house?','Yes, that is my house.', [('house','дом'),('door','дверь'),('window','окно')]),
('Числа','Считаем до пяти','I have two apples.','У меня два яблока.','I have ___ apples.','two','I have two apple.','После two существительное apple получает окончание множественного числа -s.','How many apples do you have?','I have two apples.', [('one','один'),('two','два'),('five','пять')]),
('Числа','Возраст и числа','I am ten years old.','Мне десять лет.','I am ___ years old.','ten','I have ten years old.','Возраст выражается с be: I am ten years old.','How old are you?','I am ten years old.', [('six','шесть'),('ten','десять'),('twenty','двадцать')]),
('Семья','Моя семья','This is my sister.','Это моя сестра.','This is my ___.','sister','This is me sister.','Перед существительным используется my («мой/моя»), а не me.','Who is this?','This is my sister.', [('sister','сестра'),('brother','брат'),('mother','мать')]),
('Семья','Наши близкие','My father is a doctor.','Мой отец — врач.','My father ___ a doctor.','is','My father are a doctor.','My father — единственное число, поэтому нужна форма is. Перед профессией нужен a.','What does your father do?','He is a doctor.', [('father','отец'),('parent','родитель'),('family','семья')]),
('Еда и напитки','Время обеда','I like rice.','Мне нравится рис.','I ___ rice.','like','I likes rice.','В Present Simple с I используется like без окончания -s.','What food do you like?','I like rice.', [('rice','рис'),('bread','хлеб'),('cheese','сыр')]),
('Еда и напитки','В кафе','I would like some water.','Я хотел бы немного воды.','I would like some ___.','water','I would likes some water.','После would используется начальная форма like. Some water — немного воды.','What would you like to drink?','Some water, please.', [('water','вода'),('tea','чай'),('milk','молоко')]),
('Цвета и предметы','Палитра','The bag is blue.','Сумка синяя.','The bag is ___.','blue','The bag are blue.','The bag — единственное число: is. Прилагательные цвета не изменяются.','What colour is the bag?','It is blue.', [('blue','синий'),('red','красный'),('green','зелёный')]),
('Цвета и предметы','На столе','The cup is on the table.','Чашка на столе.','The cup is ___ the table.','on','The cup on the table.','В английском предложении нужна связка is. On означает «на поверхности».','Where is the cup?','It is on the table.', [('cup','чашка'),('table','стол'),('chair','стул')]),
('Повседневные действия','Моё утро','I eat breakfast at home.','Я завтракаю дома.','I eat breakfast ___ home.','at','I eats breakfast at home.','С I глагол eat не получает -s. At home — устойчивое сочетание «дома».','Where do you eat breakfast?','I eat breakfast at home.', [('eat','есть'),('sleep','спать'),('read','читать')]),
('Повседневные действия','Каждый день','She walks to school.','Она ходит в школу пешком.','She ___ to school.','walks','She walk to school.','В Present Simple после she к walk добавляется -s.','How does she get to school?','She walks to school.', [('walk','ходить пешком'),('run','бегать'),('write','писать')]),
('Работа и учёба','На уроке','We study English.','Мы изучаем английский.','We ___ English.','study','We studies English.','После we используется study. Форма studies нужна с he/she/it.','What do you study?','We study English.', [('student','студент'),('teacher','учитель'),('lesson','урок')]),
('Работа и учёба','Моя работа','He works in an office.','Он работает в офисе.','He works ___ an office.','in','He work in an office.','После he используется works. In an office — в офисе.','Where does he work?','He works in an office.', [('work','работать'),('office','офис'),('job','работа')]),
('Путешествия','В дорогу','I need a ticket.','Мне нужен билет.','I need ___ ticket.','a','I needs a ticket.','С I используется need. Ticket — исчисляемое существительное, здесь нужен артикль a.','How can I help you?','I need a ticket.', [('ticket','билет'),('train','поезд'),('bus','автобус')]),
('Путешествия','В новом городе','The hotel is near the station.','Отель рядом со станцией.','The hotel is ___ the station.','near','The hotel are near the station.','The hotel — единственное число: is. Near — «рядом с».','Where is the hotel?','It is near the station.', [('hotel','отель'),('station','станция'),('map','карта')]),
('Базовые разговорные ситуации','Просим о помощи','Can you help me?','Можете мне помочь?','Can you ___ me?','help','Can you helps me?','После can используется начальная форма глагола: help.','Can you help me?','Yes, of course.', [('help','помогать'),('please','пожалуйста'),('sorry','извините')]),
('Базовые разговорные ситуации','В магазине','How much is this shirt?','Сколько стоит эта рубашка?','How much ___ this shirt?','is','How much are this shirt?','This shirt — единственное число: is. How much is…? — вопрос о цене.','How much is this shirt?','It is ten pounds.', [('shirt','рубашка'),('shop','магазин'),('price','цена')]),
]

# Explicitly reviewed alternatives apply to translation, not transcription.
TRANSLATION_ALTERNATIVES = {
    1: ['Hi, my name is Anna.', 'Hello, I am Anna.', 'Hi, I am Anna.'],
    2: ['I come from Russia.'],
    3: ['It is a book.'],
    4: ['That is my home.'],
    6: ['I am ten.'],
    10: ["I'd like some water.", 'I would like a little water.', "I'd like a little water."],
    11: ['The bag is blue.', 'A bag is blue.'],
    13: ['I have breakfast at home.'],
    14: ['She goes to school on foot.'],
    15: ['We learn English.'],
    19: ['Could you help me?'],
    20: ['How much does this shirt cost?'],
}

def build():
    out = Path(__file__).resolve().parents[1] / 'assets' / 'courses'
    out.mkdir(parents=True, exist_ok=True)
    manifest = {'id': 'en-ru-a1', 'version': 1, 'title': 'Английский · A1', 'sourceLanguage':'ru', 'targetLanguage':'en', 'sections': []}
    for n, (topic,title,en,ru,gap,missing,wrong,why,dialogue,reply,words) in enumerate(LESSONS):
        lid = f'a1-{n+1:02d}'
        vocab = [{'id':f'en:{w}', 'en':w, 'ru':r} for w,r in words]
        def ex(kind, prompt, answers, **kw):
            return dict(type=kind, prompt=prompt, answers=answers, explanation=why, wordIds=[vocab[0]['id']], **kw)
        exercises = [
            ex('choice', f'Как переводится «{words[0][0]}»?', [words[0][1]], options=[words[1][1],words[0][1],words[2][1],'вчера']),
            ex('translate', ru, [en]),
            ex('order', ru, [en], tokens=en.replace('.','').replace('?','').replace(',','').split()),
            ex('gap', gap, [missing]),
            ex('listen', 'Послушайте и запишите фразу по-английски.', [en], audio=en),
            dict(type='pairs', prompt='Соедините английские слова с переводами.', answers=['matched'], explanation='Сравните каждое английское слово с его переводом.', pairs=vocab, wordIds=[v['id'] for v in vocab]),
            ex('speak', en, [en], audio=en),
            ex('correct', wrong, [en]),
            ex('review', f'Напишите по-английски: {words[0][1]}', [words[0][0]]),
            ex('dialogue', dialogue, [reply], options=[reply,'Goodbye, see you tomorrow.','My favourite colour is yellow.','I have a small cat.']),
        ]
        exercises[0]['explanation']=f"{words[0][0]} — {words[0][1]}."
        exercises[8]['explanation']=exercises[0]['explanation']
        exercises[9]['explanation']=f'Подходящая реплика: {reply}'
        exercises[1]['answers'] = list(dict.fromkeys([en, *TRANSLATION_ALTERNATIVES.get(n+1, [])]))
        for e in exercises:
            if e['type'] in ('translate','order','gap','listen','speak','correct','dialogue'):
                text = ' '.join(e['answers']).lower()
                e['wordIds'] = [v['id'] for v in vocab if re.search(r'\b'+re.escape(v['en'])+r'\b',text)]
        for i,e in enumerate(exercises): e['id']=f'{lid}-e{i+1:02d}'
        lesson={'id':lid,'title':title,'topic':topic,'section':n//10,'theme':n//2,'order':n,'guide':why,'vocabulary':vocab,'exercises':exercises}
        (out/f'{lid}.json').write_text(json.dumps(lesson, ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        if n%10==0: manifest['sections'].append({'id':f's{n//10+1}','title':['Первые сигналы','Новые горизонты'][n//10], 'themes':[]})
        if n%2==0: manifest['sections'][-1]['themes'].append({'id':f't{n//2+1}','title':topic,'lessons':[]})
        manifest['sections'][-1]['themes'][-1]['lessons'].append({'id':lid,'title':title,'asset':f'assets/courses/{lid}.json','order':n})
    (out/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Authored {len(LESSONS)} lessons / {len(LESSONS)*10} exercises')

if __name__ == '__main__': build()
