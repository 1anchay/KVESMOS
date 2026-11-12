"""Reproducible, editorially authored A1 material. Never edits installed packs."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Each entry is a deliberate teaching sequence, not random sentence generation.
# step: title | example | translation | explanation
# task: type | prompt | accepted answers (; separated) | explanation | extra
COURSE = [
    (7, 'Представить семью и сказать возраст близкого.', 'family-introduction', [
        ('Моя сестра', 'This is my sister.', 'Это моя сестра.', 'Sister — сестра. Знакомое This is my… помогает представить человека.'),
        ('Он и она', 'She is ten. He is six.', 'Ей десять. Ему шесть.', 'She — она, he — он. После he и she используем is. Возраст, как и раньше, выражаем через be, без years.'),
        ('Семейный альбом', 'This is my brother. This is my mother.', 'Это мой брат. Это моя мама.', 'Brother — брат, mother — мама. My не меняется: my sister, my brother, my mother.'),
    ], [
        ('choice', 'Мико показывает сестру. Как её представить?', 'This is my sister.', 'Sister — сестра; brother — брат.', ['This is my sister.', 'This is my brother.', 'This is my book.']),
        ('pairs', 'Подпиши три фотографии в альбоме.', '', 'Соедини родство с переводом.', None),
        ('order', 'Собери подпись: «Это моя мама».', 'This is my mother', 'После This ставим is, затем my mother.', None),
        ('gap', 'Сестре десять: She ___ ten.', 'is', 'После she нужна форма is.', None),
        ('listen', 'Послушай подпись к фотографии. Кто это?', 'brother', 'В записи brother — брат.', ['brother', 'mother', 'sister'], 'This is my brother.'),
        ('correct', 'Зиг написал: He am six. Исправь предложение.', 'He is six.', 'Am подходит только к I. С he используем is.', None),
        ('translate', 'Скажи: «Это моя сестра».', 'This is my sister.', 'Используй This is my и слово sister.', None),
        ('dialogue', 'Помоги Мико подписать фотографию мамы.', 'This is my mother.', 'Mother — мама. Отвечаем о человеке на фотографии.', ['This is my mother.', 'This is my sister.', 'This is my pen.'], None, 'Мико: Это мой семейный альбом.\nМико: Подпишем мамину фотографию.\nТы: …'),
        ('order', 'На следующей фотографии брат. Собери подпись.', 'This is my brother', 'Меняется только слово родства.', None),
        ('dialogue', 'Брату шесть. Добавь возраст к подписи.', 'He is six.;My brother is six.', 'О брате говорим he; после he — is.', None, None, 'Мико: This is my brother.\nМико: Добавим его возраст — шесть лет.\nТы: …'),
    ], 'Альбом Мико'),
    (8, 'Рассказать о родителях и семье во множественном числе.', 'family-plural', [
        ('Папа и семья', 'This is my father. This is my family.', 'Это мой папа. Это моя семья.', 'Father — папа, family — семья. Family здесь обозначает одну семью: is.'),
        ('Родители', 'These are my parents.', 'Это мои родители.', 'Parent — один родитель; parents — родители. These are — «это» для нескольких людей или предметов.'),
        ('Мы вместе', 'We are a family.', 'Мы — семья.', 'We — мы. После we используем are. Перед одной семьёй говорим a family.'),
    ], [
        ('choice', 'На встречу пришли оба родителя. Выбери подпись.', 'These are my parents.', 'Несколько человек: These are, а не This is.', ['These are my parents.', 'This is my father.', 'This is my sister.']),
        ('pairs', 'Соедини новые слова.', '', 'Parent — один родитель, family — вся семья.', None),
        ('order', 'Собери: «Мы — семья».', 'We are a family', 'После we нужна форма are.', None),
        ('gap', 'These ___ my parents.', 'are', 'После these используем are.', None),
        ('listen', 'Какое слово звучит в конце фразы?', 'father', 'Father — папа.', ['father', 'mother', 'brother'], 'This is my father.'),
        ('correct', 'Исправь: We is a family.', 'We are a family.', 'We требует are, а не is.', None),
        ('translate', 'Представь папу одним предложением.', 'This is my father.', 'Знакомая конструкция This is my…', None),
        ('dialogue', 'Мико знакомит тебя с родителями. Поздоровайся.', 'Hello!;Hi!', 'Для приветствия достаточно Hello или Hi.', ['Hello!', 'Goodbye!', 'I am ten.'], None, 'Мико: These are my parents.\nТы: …'),
        ('review', 'Вспомни: как сказать «моя сестра»?', 'my sister', 'My одинаково подходит к sister и father.', None),
        ('speak', 'Представь родителей: «Это мои родители». Произнеси или напиши.', 'These are my parents.', 'These are — для нескольких людей.', None, 'These are my parents.'),
    ], None),
    (9, 'Рассказать, какая еда нравится, и спросить друга.', 'food-like', [
        ('Обед на станции', 'I like rice.', 'Мне нравится рис.', 'Rice — рис, bread — хлеб, cheese — сыр. I like… означает «мне нравится…». Перед этими названиями еды не ставим a.'),
        ('Вопрос другу', 'Do you like cheese?', 'Тебе нравится сыр?', 'Do you like…? — вопрос о предпочтении. Короткие ответы: Yes, I do. / No, I don’t.'),
        ('Что не нравится', 'I do not like bread.', 'Мне не нравится хлеб.', 'Для отрицания добавь do not перед like. Don’t — сокращение do not; оба варианта допустимы.'),
    ], [
        ('choice', 'Орби любит рис. Выбери его реплику.', 'I like rice.', 'I like — мне нравится; rice — рис.', ['I like rice.', 'I like cheese.', 'I do not like rice.']),
        ('pairs', 'Собери подписи для обеда.', '', 'Rice — рис, bread — хлеб, cheese — сыр.', None),
        ('order', 'Спроси: «Тебе нравится сыр?»', 'Do you like cheese', 'Вопрос начинается с Do you, затем like.', None),
        ('gap', 'I do ___ like bread.', 'not', 'Do not делает предложение отрицательным.', None),
        ('listen', 'Что нравится Мико?', 'bread', 'В записи I like bread — мне нравится хлеб.', ['bread', 'rice', 'cheese'], 'I like bread.'),
        ('correct', 'Исправь порядок: You do like rice?', 'Do you like rice?', 'В нейтральном вопросе Do ставим перед you.', None),
        ('translate', 'Скажи: «Мне не нравится сыр».', 'I do not like cheese.;I don’t like cheese.', 'Do not или don’t стоит перед like.', None),
        ('dialogue', 'Ответь положительно на вопрос Орби.', 'Yes, I do.', 'На Do you like…? отвечаем Yes, I do.', ['Yes, I do.', 'No, I don’t.', 'I am ten.'], None, 'Орби: Do you like rice?\nТы: …'),
        ('review', 'Вспомни, как представить друга.', 'This is my friend.', 'Друг — friend. This is my friend.', None),
        ('speak', 'Скажи, что тебе нравится сыр.', 'I like cheese.', 'Не добавляй am: I like, а не I am like.', None, 'I like cheese.'),
    ], None),
    (10, 'Вежливо заказать напиток и поблагодарить.', 'cafe-request', [
        ('Напитки', 'Water, tea, milk.', 'Вода, чай, молоко.', 'Water — вода, tea — чай, milk — молоко. Эти слова обычно употребляются без a.'),
        ('Заказ', 'Can I have tea, please?', 'Можно мне чай, пожалуйста?', 'Запомни вежливую конструкцию Can I have…? Please смягчает просьбу. Это готовая фраза для заказа.'),
        ('Спасибо', 'Thank you. You are welcome.', 'Спасибо. Пожалуйста.', 'Thank you или Thanks — благодарность. You’re welcome — сокращение You are welcome. You are welcome — ответ на благодарность; это не please в просьбе.'),
    ], [
        ('choice', 'Ты хочешь воду. Выбери вежливый заказ.', 'Can I have water, please?', 'В просьбе используем please.', ['Can I have water, please?', 'Can I have milk, please?', 'I do not like water.']),
        ('pairs', 'Подбери перевод напиткам.', '', 'Не путай tea — чай и milk — молоко.', None),
        ('order', 'Собери заказ чая.', 'Can I have tea please', 'Can I have, затем напиток и please.', None),
        ('gap', 'Can I ___ milk, please?', 'have', 'В знакомой просьбе используется have.', None),
        ('listen', 'Какой напиток заказывает Зиг?', 'milk', 'Зиг просит молоко.', ['milk', 'water', 'tea'], 'Can I have milk, please?'),
        ('correct', 'В просьбе перепутали слова: Can have I tea, please?', 'Can I have tea, please?', 'После Can ставим I, затем have.', None),
        ('translate', 'Поблагодари за напиток.', 'Thank you.;Thanks.', 'Thank you и Thanks — естественные способы поблагодарить.', None),
        ('dialogue', 'Закажи чай в кафе Мико.', 'Can I have tea, please?', 'Укажи tea, сохрани вежливую форму.', ['Can I have tea, please?', 'I am tea.', 'Can I have bread, please?'], None, 'Мико: Hello!\nТы: …'),
        ('review', 'Вспомни: «Мне нравится хлеб».', 'I like bread.', 'Для предпочтения говорим I like…', None),
        ('dialogue', 'Тебе сказали Thank you. Ответь вежливо.', 'You are welcome.;You’re welcome.', 'You are welcome — ответ на благодарность.', None, None, 'Мико: Thank you!\nТы: …'),
    ], None),
    (11, 'Описать цвет предмета и уточнить нужный предмет.', 'colors', [
        ('Три цвета', 'The bag is blue.', 'Сумка синяя.', 'Blue — синий, red — красный, green — зелёный. The означает, что речь об известном предмете, например сумке перед нами.'),
        ('Цвет перед предметом', 'This is a red pen.', 'Это красная ручка.', 'В английском цвет ставим перед предметом: a red pen, a green book.'),
        ('Вопрос о цвете', 'Is the bag blue?', 'Сумка синяя?', 'Для вопроса с is переставляем is в начало. Ответ: Yes, it is. / No, it is not.'),
    ], [
        ('choice', 'Нужна красная ручка. Выбери её подпись.', 'a red pen', 'Цвет стоит перед названием предмета.', ['a red pen', 'a blue pen', 'a green book']),
        ('pairs', 'Соедини цвета и переводы.', '', 'Blue — синий, red — красный, green — зелёный.', None),
        ('order', 'Собери: «Сумка синяя».', 'The bag is blue', 'Известный предмет: the bag. Затем is и цвет.', None),
        ('gap', 'Это зелёная книга: This is a ___ book.', 'green', 'Green — зелёный.', None),
        ('listen', 'Какого цвета ручка?', 'red', 'Red означает красный.', ['red', 'blue', 'green'], 'The pen is red.'),
        ('correct', 'Исправь порядок: This is a pen blue.', 'This is a blue pen.', 'Цвет blue ставим перед pen.', None),
        ('translate', 'Спроси: «Сумка синяя?»', 'Is the bag blue?', 'Вопрос начинается с Is.', None),
        ('dialogue', 'Ответь: да, сумка синяя.', 'Yes, it is.', 'В коротком ответе bag заменяем на it.', ['Yes, it is.', 'No, it is not.', 'Yes, I do.'], None, 'Зиг: Is the bag blue?\nТы: …'),
        ('review', 'Попроси воду вежливо.', 'Can I have water, please?;Water, please.', 'В просьбе о воде добавь please.', None),
        ('speak', 'Опиши предмет: «Это зелёная книга».', 'This is a green book.', 'A green book — зелёная книга.', None, 'This is a green book.'),
    ], None),
    (12, 'Найти предмет и описать, где он находится.', 'location-on-under', [
        ('За столом', 'This is a table. This is a chair. This is a cup.', 'Это стол. Это стул. Это чашка.', 'Table — стол, chair — стул, cup — чашка.'),
        ('На и под', 'The book is on the table.', 'Книга на столе.', 'On — на поверхности, under — под предметом. The book is under the chair — книга под стулом.'),
        ('Где предмет?', 'Where is my book?', 'Где моя книга?', 'Where is…? спрашивает о местоположении одного предмета. Ответ: It is on the table.'),
    ], [
        ('choice', 'Книга лежит на столе. Выбери описание.', 'The book is on the table.', 'On — на, under — под.', ['The book is on the table.', 'The book is under the table.', 'The book is blue.']),
        ('pairs', 'Подпиши предметы в комнате.', '', 'Cup — чашка, table — стол, chair — стул.', None),
        ('order', 'Спроси: «Где моя книга?»', 'Where is my book', 'Where is, затем my book.', None),
        ('gap', 'Сумка под стулом: The bag is ___ the chair.', 'under', 'Under показывает расположение под предметом.', None),
        ('listen', 'Где чашка?', 'on the table', 'Чашка находится на столе.', ['on the table', 'under the chair', 'under the table'], 'The cup is on the table.'),
        ('correct', 'Исправь вопрос: Where my book is?', 'Where is my book?', 'В вопросе is стоит после where, перед предметом.', None),
        ('translate', 'Скажи: «Сумка под столом».', 'The bag is under the table.', 'Известные предметы: the bag, the table.', None),
        ('dialogue', 'Мико потерял книгу. Ты видишь её под стулом. Ответь.', 'It is under the chair.', 'It заменяет book; under the chair — под стулом.', ['It is under the chair.', 'It is on the table.', 'It is a cup.'], None, 'Мико: Where is my book?\nТы: …'),
        ('order', 'Рядом две книги. Уточни: «Книга зелёная».', 'The book is green', 'Цвет поможет Мико выбрать нужную книгу.', None),
        ('dialogue', 'Мико нашёл книгу и благодарит. Заверши разговор.', 'You are welcome.;You’re welcome.', 'На Thank you отвечаем You are welcome.', None, None, 'Мико: The green book! Thank you!\nТы: …'),
    ], 'Пропавшая книга'),
    (13, 'Рассказать о простых привычках в течение дня.', 'daily-present', [
        ('Действия', 'I eat rice. I read a book. I sleep.', 'Я ем рис. Я читаю книгу. Я сплю.', 'Eat — есть, read — читать, sleep — спать. После I используем действие без am.'),
        ('Время дня', 'I read in the morning. I sleep at night.', 'Я читаю утром. Я сплю ночью.', 'In the morning — утром, at night — ночью. Запомни разные предлоги в этих выражениях.'),
        ('Обычный день', 'I eat bread every day.', 'Я ем хлеб каждый день.', 'Every day — каждый день. Для обычного действия используем простое настоящее время.'),
    ], [
        ('choice', 'Выбери привычку: «Я читаю утром».', 'I read in the morning.', 'Read — читать; in the morning — утром.', ['I read in the morning.', 'I sleep at night.', 'I eat cheese.']),
        ('pairs', 'Соедини действия и переводы.', '', 'Eat — есть, sleep — спать, read — читать.', None),
        ('order', 'Собери: «Я сплю ночью».', 'I sleep at night', 'At night — устойчивое выражение «ночью».', None),
        ('gap', 'Я ем рис: I ___ rice.', 'eat', 'Eat — есть. Am здесь не нужен.', None),
        ('listen', 'Что делает Орби утром?', 'read', 'Он говорит I read in the morning.', ['read', 'eat', 'sleep'], 'I read in the morning.'),
        ('correct', 'Исправь: I am read a book.', 'I read a book.', 'Для обычного действия I read; am не ставится перед read.', None),
        ('translate', 'Скажи: «Я ем хлеб каждый день».', 'I eat bread every day.', 'Every day ставим в конце этой фразы.', None),
        ('dialogue', 'Орби спрашивает, читаешь ли ты каждый день. Ответь да.', 'Yes, I do.', 'Знакомый вопрос Do you…? работает и с read.', ['Yes, I do.', 'Yes, it is.', 'No, I do not.'], None, 'Орби: Do you read every day?\nТы: …'),
        ('review', 'Скажи: «Книга на столе».', 'The book is on the table.', 'Состояние предмета требует is; действие I read — нет.', None),
        ('speak', 'Расскажи: «Я читаю книгу».', 'I read a book.', 'Перед одной книгой используем a.', None, 'I read a book.'),
    ], None),
    (14, 'Спросить о привычке и рассказать о действиях друга.', 'third-person', [
        ('Новые действия', 'I walk. I run. I write.', 'Я хожу пешком. Я бегаю. Я пишу.', 'Walk — ходить пешком, run — бегать, write — писать.'),
        ('Он и она действуют', 'She reads. He runs.', 'Она читает. Он бегает.', 'После he и she к обычному действию добавляем -s: reads, walks, runs, writes.'),
        ('Вопрос и отрицание', 'Does he run? He does not run.', 'Он бегает? Он не бегает.', 'С he/she используем does. После does или does not действие без -s: run. Doesn’t — сокращение does not.'),
    ], [
        ('choice', 'Расскажи о привычке Мико: «Он пишет».', 'He writes.', 'После he нужна форма writes.', ['He writes.', 'He write.', 'He is write.']),
        ('pairs', 'Соедини действия.', '', 'Walk — идти пешком, run — бегать, write — писать.', None),
        ('order', 'Спроси: «Она ходит пешком?»', 'Does she walk', 'Does she + действие без -s.', None),
        ('gap', 'Он бегает: He ___.', 'runs', 'После he добавляем -s.', None),
        ('listen', 'Что делает она каждый день?', 'write', 'She writes every day — она пишет каждый день.', ['write', 'walk', 'run'], 'She writes every day.'),
        ('correct', 'Исправь: Does he runs?', 'Does he run?', 'После does окончание -s у действия убираем.', None),
        ('translate', 'Скажи: «Он не бегает».', 'He does not run.;He doesn’t run.', 'Does not / doesn’t + run.', None),
        ('dialogue', 'Ответь положительно о привычке Мико.', 'Yes, he does.', 'После Does he…? короткий ответ Yes, he does.', ['Yes, he does.', 'Yes, I do.', 'Yes, it is.'], None, 'Зиг: Does he read every day?\nТы: …'),
        ('review', 'Вспомни: «Я сплю ночью».', 'I sleep at night.', 'С I действие без -s; ночью — at night.', None),
        ('speak', 'Расскажи: «Она читает книгу».', 'She reads a book.', 'She reads — не she read.', None, 'She reads a book.'),
    ], None),
    (15, 'Назвать роль в классе и спросить, что это за предмет.', 'classroom-questions', [
        ('В академии', 'I am a student. She is a teacher.', 'Я ученик. Она учитель.', 'Student — ученик или студент; teacher — учитель. Перед названием роли одного человека используем a.'),
        ('На уроке', 'This is an English lesson.', 'Это урок английского.', 'Lesson — урок. English — английский. Перед гласным звуком в English используется an вместо a.'),
        ('Что это?', 'What is this? It is a pen.', 'Что это? Это ручка.', 'What is this? — вопрос о предмете. It is… — ответ. Для вопроса о роли: Are you a student? — Ты ученик?'),
    ], [
        ('choice', 'Представь свою роль ученика.', 'I am a student.', 'Student — ученик; перед ролью нужен a.', ['I am a student.', 'I am a teacher.', 'I am a lesson.']),
        ('pairs', 'Подпиши слова академии.', '', 'Lesson — занятие, teacher — учитель, student — ученик.', None),
        ('order', 'Спроси, что это за предмет.', 'What is this', 'What is this — что это?', None),
        ('gap', 'This is ___ English lesson.', 'an', 'English начинается с гласного звука: an English lesson.', None),
        ('listen', 'Кто она?', 'teacher', 'Teacher — учитель.', ['teacher', 'student', 'mother'], 'She is a teacher.'),
        ('correct', 'Исправь: I am student.', 'I am a student.', 'Перед названием одной роли нужен артикль a.', None),
        ('translate', 'Скажи: «Это урок английского».', 'This is an English lesson.;It is an English lesson.', 'Используй an перед English.', None),
        ('dialogue', 'На столе ручка. Ответь на вопрос Зига.', 'It is a pen.;This is a pen.', 'Назови предмет с a.', ['It is a pen.', 'It is a teacher.', 'I am a pen.'], None, 'Зиг: What is this?\nТы: …'),
        ('review', 'Скажи: «Она читает».', 'She reads.', 'После she у действия есть -s.', None),
        ('speak', 'Спроси собеседника, ученик ли он.', 'Are you a student?', 'Вопрос с you начинается с Are you.', None, 'Are you a student?'),
    ], None),
    (16, 'Рассказать, где работаешь, и спросить о месте работы.', 'work-place', [
        ('Работа', 'I work in an office.', 'Я работаю в офисе.', 'Work — работать, he works — он работает; office — офис. In — в помещении. Перед office ставим an.'),
        ('Профессия и занятие', 'I have a job. I am a teacher.', 'У меня есть работа. Я учитель.', 'Job — работа как место или должность: a job. Work в I work — действие, без am.'),
        ('Где работаешь?', 'Where do you work?', 'Где ты работаешь?', 'Where + do you + work. О другом человеке: Where does she work? После does — work без -s.'),
    ], [
        ('choice', 'Зиг работает в офисе. Выбери его реплику.', 'I work in an office.', 'In an office — в офисе.', ['I work in an office.', 'I am work.', 'I am a teacher.']),
        ('pairs', 'Соедини слова о работе.', '', 'Work — работать; job — работа, должность; office — офис.', None),
        ('order', 'Спроси о месте работы.', 'Where do you work', 'В вопросе об обычном действии нужен do.', None),
        ('gap', 'I have a ___. Подставь «работа, должность».', 'job', 'После a нужно исчисляемое job.', None),
        ('listen', 'Где он работает?', 'in an office', 'Он работает в офисе.', ['in an office', 'at night', 'on the table'], 'He works in an office.'),
        ('correct', 'Исправь: She work in an office.', 'She works in an office.', 'После she действие получает -s.', None),
        ('translate', 'Скажи: «У меня есть работа».', 'I have a job.', 'A job — одна работа или должность.', None),
        ('dialogue', 'Ты работаешь в офисе. Ответь Мико.', 'I work in an office.', 'Ответь полной знакомой фразой.', ['I work in an office.', 'I work on the table.', 'I am ten.'], None, 'Мико: Where do you work?\nТы: …'),
        ('review', 'Спроси: «Она читает?»', 'Does she read?', 'После does — read без -s.', None),
        ('speak', 'Спроси: «Где она работает?»', 'Where does she work?', 'Where does she + work.', None, 'Where does she work?'),
    ], None),
    (17, 'Выбрать транспорт и вежливо попросить билет.', 'travel-ticket', [
        ('В дорогу', 'I go by train. I go by bus.', 'Я еду поездом. Я еду автобусом.', 'Train — поезд, bus — автобус. Go — ехать или идти. By train / by bus — способ передвижения, без a.'),
        ('Один билет', 'Can I have a ticket, please?', 'Можно мне билет, пожалуйста?', 'Ticket — билет. Для одного билета нужен a, в отличие от water.'),
        ('Билет на поезд', 'A ticket for the train, please.', 'Билет на поезд, пожалуйста.', 'For the train уточняет, для какого транспорта билет. Two tickets — два билета, с -s.'),
    ], [
        ('choice', 'Ты едешь поездом. Выбери фразу.', 'I go by train.', 'By train — поездом.', ['I go by train.', 'I go by bus.', 'I read a book.']),
        ('pairs', 'Подготовь слова путешественника.', '', 'Ticket — билет, train — поезд, bus — автобус.', None),
        ('order', 'Попроси один билет.', 'Can I have a ticket please', 'Can I have a ticket, please — вежливая просьба.', None),
        ('gap', 'Я еду автобусом: I go ___ bus.', 'by', 'Способ передвижения: by bus.', None),
        ('listen', 'Какой транспорт нужен Мико?', 'train', 'Мико едет поездом.', ['train', 'bus', 'office'], 'I go by train.'),
        ('correct', 'Исправь: I go by a bus.', 'I go by bus.', 'После by в этом выражении артикль не нужен.', None),
        ('translate', 'Попроси два билета короткой фразой.', 'Two tickets, please.', 'После two используем tickets во множественном числе.', None),
        ('dialogue', 'Помоги Мико: нужен билет на поезд.', 'A ticket for the train, please.', 'Уточни for the train, чтобы выбрать нужный билет.', ['A ticket for the train, please.', 'A ticket for the bus, please.', 'Tea, please.'], None, 'Мико: I go by train.\nМико: Поможешь попросить билет?\nТы: …'),
        ('order', 'Мико едет с другом. Теперь попроси два билета.', 'Two tickets please', 'Число two требует tickets с -s.', None),
        ('dialogue', 'Билеты получены. Поблагодари сотрудника.', 'Thank you.;Thanks.', 'Короткое Thank you завершает покупку вежливо.', None, None, 'Зиг: Two tickets.\nТы: …'),
    ], 'Билеты для команды'),
    (18, 'Спросить дорогу и понять простые указания.', 'city-directions', [
        ('В городе', 'This is a hotel. This is a station. This is a map.', 'Это отель. Это станция. Это карта.', 'Hotel — отель, station — станция или вокзал, map — карта.'),
        ('Спросить дорогу', 'Where is the station?', 'Где вокзал?', 'Знакомая конструкция Where is…? работает и с местами. The station — нужный вокзал.'),
        ('Понять маршрут', 'Go straight. Turn left. Turn right.', 'Идите прямо. Поверните налево. Поверните направо.', 'Указание начинается с действия: Go, Turn. Straight — прямо, left — налево, right — направо.'),
    ], [
        ('choice', 'Ты ищешь вокзал. Что спросить?', 'Where is the station?', 'Station — вокзал; вопрос начинается с Where is.', ['Where is the station?', 'Where is the hotel?', 'What is this?']),
        ('pairs', 'Соедини слова на карте.', '', 'Map — карта, hotel — отель, station — вокзал.', None),
        ('order', 'Спроси, где отель.', 'Where is the hotel', 'Where is the hotel — где отель?', None),
        ('gap', 'Поверните налево: Turn ___.', 'left', 'Left — налево, right — направо.', None),
        ('listen', 'Какое указание ты услышал?', 'Идите прямо.', 'Go straight — идите прямо.', ['Идите прямо.', 'Поверните налево.', 'Поверните направо.'], 'Go straight.'),
        ('correct', 'Исправь вопрос: Where the hotel is?', 'Where is the hotel?', 'В вопросе is ставим перед the hotel.', None),
        ('translate', 'Скажи: «Поверните направо».', 'Turn right.', 'Turn — поверните, right — направо.', None),
        ('dialogue', 'Команда ищет отель. Спроси Орби о нём.', 'Where is the hotel?', 'Выбери вопрос именно об отеле.', ['Where is the hotel?', 'Where is the station?', 'I go by train.'], None, 'Орби: Hello!\nТы: …'),
        ('choice', 'Орби ответил. Какой первый шаг маршрута?', 'Идти прямо.', 'Сначала Go straight, затем Turn left.', ['Идти прямо.', 'Повернуть направо.', 'Ехать поездом.'], None, 'Орби: Go straight. Turn left.'),
        ('dialogue', 'Маршрут понятен. Поблагодари проводника.', 'Thank you.;Thanks.', 'Благодарность завершает разговор.', None, None, 'Орби: The hotel!\nТы: …'),
    ], 'Карта нового города'),
    (19, 'Вежливо попросить помощи и переспросить.', 'asking-help', [
        ('Нужна помощь', 'Can you help me, please?', 'Можете мне помочь, пожалуйста?', 'Help — помогать. Can you…? — просьба к собеседнику, me — мне. Не путай с Can I have…?'),
        ('Обратиться вежливо', 'Excuse me. Where is the station?', 'Извините. Где вокзал?', 'Excuse me привлекает внимание незнакомого человека. Sorry — извинение за ошибку или неудобство.'),
        ('Переспросить', 'Sorry. Can you repeat, please?', 'Извините. Можете повторить, пожалуйста?', 'Repeat — повторить. Эта готовая просьба поможет, если фраза прозвучала слишком быстро.'),
    ], [
        ('choice', 'Попроси собеседника помочь.', 'Can you help me, please?', 'Просьба к собеседнику начинается с Can you.', ['Can you help me, please?', 'Can I have milk, please?', 'I am help.']),
        ('pairs', 'Соедини слова вежливого общения.', '', 'Help — помощь или помогать, please — пожалуйста, sorry — извините.', None),
        ('order', 'Попроси повторить.', 'Can you repeat please', 'Can you repeat, please — можете повторить?', None),
        ('gap', 'Can you help ___, please?', 'me', 'Me означает «мне» в этой просьбе.', None),
        ('listen', 'О чём просит Орби?', 'Повторить.', 'Repeat — повторить.', ['Повторить.', 'Дать билет.', 'Повернуть налево.'], 'Can you repeat, please?'),
        ('correct', 'Исправь: Can you me help, please?', 'Can you help me, please?', 'Порядок: help me, действие перед получателем помощи.', None),
        ('translate', 'Вежливо привлеки внимание: «Извините».', 'Excuse me.', 'Чтобы начать разговор, говорим Excuse me.', None),
        ('dialogue', 'Ты не расслышал указание. Попроси повторить.', 'Can you repeat, please?;Sorry. Can you repeat, please?', 'Повторить — repeat. Ошибаться и переспрашивать нормально.', ['Can you repeat, please?', 'Thank you.', 'I have a book.'], None, 'Зиг: Go straight. Turn right.\nТы: …'),
        ('review', 'Вспомни: «Где вокзал?»', 'Where is the station?', 'Where is…? — где находится…?', None),
        ('speak', 'Самостоятельно попроси помощи.', 'Can you help me, please?', 'Can you help me, please — законченная просьба.', None, 'Can you help me, please?'),
    ], None),
    (20, 'Выбрать вещь в магазине и спросить цену.', 'shopping-price', [
        ('В магазине', 'This is a shop. This is a shirt.', 'Это магазин. Это рубашка.', 'Shop — магазин, shirt — рубашка. A blue shirt — синяя рубашка: цвет ставим перед вещью.'),
        ('Цена', 'What is the price?', 'Какая цена?', 'Price — цена. Естественный вопрос о конкретной вещи: How much is this shirt? — Сколько стоит эта рубашка?'),
        ('Ответ о цене', 'It is ten dollars.', 'Она стоит десять долларов.', 'Dollar — доллар, после ten — dollars. It заменяет shirt. Для покупки пригодится знакомое Can I have…?'),
    ], [
        ('choice', 'Тебе нужна синяя рубашка. Выбери её.', 'a blue shirt', 'Цвет стоит перед shirt.', ['a blue shirt', 'a red shirt', 'a green bag']),
        ('pairs', 'Соедини слова магазина.', '', 'Shirt — рубашка, shop — магазин, price — цена.', None),
        ('order', 'Спроси цену этой рубашки.', 'How much is this shirt', 'How much is…? — сколько стоит…?', None),
        ('gap', 'Цена десять долларов: It is ten ___.', 'dollars', 'После ten слово dollars во множественном числе.', None),
        ('listen', 'Сколько стоит рубашка?', 'twenty', 'It is twenty dollars — двадцать долларов.', ['twenty', 'ten', 'five'], 'It is twenty dollars.'),
        ('correct', 'Исправь: This is a shirt blue.', 'This is a blue shirt.', 'Цвет blue должен стоять перед shirt.', None),
        ('translate', 'Спроси: «Какая цена?»', 'What is the price?', 'Price — цена. Используй What is the price?', None),
        ('dialogue', 'Помоги Мико купить синюю рубашку. Спроси её цену.', 'How much is this shirt?', 'Уточни стоимость рубашки, а не её цвет.', ['How much is this shirt?', 'Where is the station?', 'Do you like rice?'], None, 'Мико: This is a blue shirt.\nТы: …'),
        ('order', 'Цена подходит. Попроси рубашку.', 'Can I have this shirt please', 'Знакомая просьба Can I have… подходит и в магазине.', None),
        ('dialogue', 'Покупка завершена. Поблагодари и попрощайся.', 'Thank you. Goodbye!;Thanks. Goodbye!;Thank you. Bye!', 'Используй две знакомые фразы: благодарность и прощание.', None, None, 'Зиг: A blue shirt.\nТы: …'),
    ], 'Подарок из путешествия'),
]

def main():
    skills = ['greeting', 'introduce-friend', 'objects-my', 'this-that', 'have-plural', 'age-numbers']
    skillmap = []
    for n in range(1, 7):
        d = json.loads((ROOT / f'assets/courses/demo/a1-{n:02}.json').read_text(encoding='utf-8'))
        skillmap.append({'lesson': d['id'], 'objective': d['objective'], 'requires': skills[:n-1], 'provides': [skills[n-1]], 'words': [v['id'] for v in d['vocabulary']]})
    for n, objective, skill, steps, tasks, story in COURSE:
        lid = f'a1-{n:02}'
        original = json.loads((ROOT / f'assets/courses/{lid}.json').read_text(encoding='utf-8'))
        words = original['vocabulary']
        characters = ['orbi', 'miko', 'zig_quartz']
        d = {k: original[k] for k in ['id', 'title', 'topic', 'order', 'vocabulary']}
        d.update(materialVersion=3, objective=objective, guide=' '.join(s[3] for s in steps))
        d['teachingSteps'] = [dict(character=characters[i % 3], title=s[0], phrase=s[1], translation=s[2], explanation=s[3]) for i, s in enumerate(steps)]
        d['exercises'] = []
        for i, task in enumerate(tasks):
            kind, prompt, answers, explanation, options, *extra = task
            audio = extra[0] if extra else None
            scene = extra[1] if len(extra)>1 else None
            e = dict(id=f'{lid}-v3-{i+1:02}', type=kind, prompt=prompt, answers=answers.split(';'), explanation=explanation, hint=explanation, character=characters[i % 3], phase=['Знакомство','Знакомство','Понимание','Понимание','Понимание','Практика','Практика','Закрепление','Закрепление','Закрепление'][i])
            # Tag words only when the actual prompt/answer/audio practices them.
            text=' '.join([prompt,answers,audio or '',scene or '']).lower()
            vocab={v['id']:v for p in sorted((ROOT/'assets/courses').glob('a1-*.json')) for v in json.loads(p.read_text(encoding='utf-8'))['vocabulary']}
            import re
            known={v['id'] for row in skillmap for v in [vocab[w] for w in row['words']]} | {v['id'] for v in words}
            e['wordIds']=[wid for wid,v in vocab.items() if wid in known and re.search(r'\b'+re.escape(v['en'])+r'(?:s)?\b',text)]
            if kind=='pairs':
                e['pairs']=words
                e['answers']=['matched']
                e['wordIds']=[v['id'] for v in words]
            if kind=='order': e['tokens']=e['answers'][0].split()
            if options: e['options']=options
            if audio: e['audio']=audio
            if scene: e['scene']=scene
            if story and i>=7:
                e['story']={'id':f'{lid}-story','title':story,'step':i-6,'total':3}
            d['exercises'].append(e)
        (ROOT/f'assets/courses/demo/{lid}.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        skillmap.append({'lesson':lid,'objective':objective,'requires':skills.copy(),'provides':[skill],'words':[v['id'] for v in words]})
        skills.append(skill)
    (ROOT/'assets/courses/skills.json').write_text(json.dumps({'version':1,'lessons':skillmap},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    lines=['# Карта навыков KVESMOS A1','', '20 последовательных вводных уроков. Это основы A1, а не подтверждение освоения всего CEFR A1.', '', '| Урок | Цель | Новые слова | Навык |', '|---|---|---|---|']
    for row in skillmap: lines.append(f"| {row['lesson']} | {row['objective']} | {', '.join(w[3:] for w in row['words'])} | {row['provides'][0]} |")
    lines += ['', 'Каждый новый урок опирается на предыдущие навыки. Служебные выражения (артикли, вопросы, вежливость, время суток) объяснены во вводных шагах; не каждое служебное слово становится отдельной карточкой словаря. Старые wordId сохранены. Новые сессии получают materialVersion 3, активные продолжают закреплённый материал.', '', 'Мини-истории: семейный альбом (7), пропавшая книга (12), билеты для команды (17), карта города (18), подарок из путешествия (20). Три последовательных действия сохраняются обычной сессией; неверный выбор даёт объяснение и повторную попытку без потери XP.']
    (ROOT/'docs/A1-SKILLS.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')

if __name__=='__main__': main()
