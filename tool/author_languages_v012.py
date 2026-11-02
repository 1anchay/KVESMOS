"""Author only the twelve new courses; never rewrite the forty shipped lessons.

Mandarin uses simplified Hanzi and tone-marked pinyin, explicit phrase chunks,
and recognition before recall. No Latin transliteration is sent to Chinese TTS.
"""
import json
from pathlib import Path

# Four taught phrases: target, Russian, pronunciation (Mandarin only).
FR = [
('Bonjour · первый разговор', 'Поздороваться и ответить на вопрос о делах.',
 'Bonjour — дневное приветствие, salut — неформальное. В ça va буква ç читается как «с». Вопрос Ça va ? и ответ Ça va. различаются интонацией. Merci — спасибо.',
 [('Bonjour !','Здравствуйте!'), ('Ça va ?','Как дела?'), ('Ça va, merci.','Хорошо, спасибо.'), ('Au revoir !','До свидания!')],
 [('bonjour','здравствуйте'),('merci','спасибо'),('salut','привет')],
 ('Орби: «Ça va ?» Ответь: хорошо, спасибо.',2), ('Ça ___, merci.', 'va', ['vas','vais'])),
('Je m’appelle · знакомимся', 'Назвать своё имя и спросить имя друга.',
 'Je m’appelle… — меня зовут… Перед гласной me сокращается до m’ (апостроф сохраняется). Tu t’appelles… — тебя зовут… Enchanté говорит мужчина, enchantée — женщина; звучат одинаково. Здесь представляется Анна: enchantée.',
 [('Je m’appelle Anna.','Меня зовут Анна.'), ('Comment tu t’appelles ?','Как тебя зовут?'), ('Je viens de Russie.','Я из России.'), ('Enchantée !','Очень приятно! (говорит женщина)')],
 [('le prénom','имя'),('la Russie','Россия'),('la France','Франция')],
 ('Мико: «Comment tu t’appelles ?» Представься как Анна.',0), ('Je ___ Anna.', 'm’appelle', ['t’appelles','s’appelle'])),
('Числа и возраст', 'Посчитать до пяти и назвать возраст.',
 'Un, deux, trois, quatre, cinq — один, два, три, четыре, пять. Возраст во французском «имеют»: j’ai vingt ans — мне двадцать лет. Je + ai сокращается до j’ai. В vingt ans конечное t связывается с гласной следующего слова; конечное s в ans не произносится.',
 [('Un, deux, trois.','Один, два, три.'), ('Quatre, cinq.','Четыре, пять.'), ('J’ai vingt ans.','Мне двадцать лет.'), ('Tu as quel âge ?','Сколько тебе лет?')],
 [('deux','два'),('trois','три'),('cinq','пять')],
 ('Орби: «Tu as quel âge ?» Скажи, что тебе двадцать лет.',2), ('J’___ vingt ans.', 'ai', ['as','est'])),
('Вещи · un и une', 'Назвать предмет вместе с артиклем.',
 'Un livre — книга (мужской род), une table — стол (женский род), un sac — сумка (мужской род). Род не совпадает с русским: учим слово вместе с артиклем. C’est… — это…; ce + est сокращается до c’est. Qu’est-ce que c’est ? — что это?',
 [('C’est un livre.','Это книга.'), ('C’est une table.','Это стол.'), ('C’est un sac.','Это сумка.'), ('Qu’est-ce que c’est ?','Что это?')],
 [('un livre','книга'),('une table','стол'),('un sac','сумка')],
 ('Мико показывает книгу: «Qu’est-ce que c’est ?» Назови её.',0), ('C’est ___ table.', 'une', ['un','des'])),
('Моя семья', 'Представить близких.',
 'Ma mère — моя мама, mon père — мой папа, ma sœur — моя сестра. Ma и mon зависят от рода существительного, а не от того, кто говорит. Elle s’appelle… — её зовут… Здесь sœur пишется с œ; вариант soeur тоже принимается при вводе.',
 [('C’est ma mère.','Это моя мама.'), ('C’est mon père.','Это мой папа.'), ('C’est ma sœur.','Это моя сестра.'), ('Elle s’appelle Anna.','Её зовут Анна.')],
 [('ma mère','моя мама'),('mon père','мой папа'),('ma sœur','моя сестра')],
 ('Орби спрашивает имя твоей сестры. Скажи: её зовут Анна.',3), ('C’est ___ mère.', 'ma', ['mon','mes'])),
('В кафе · просьбы', 'Вежливо попросить напиток и счёт.',
 'Je voudrais… — я хотел(а) бы… Un café — чашка кофе. De l’eau — воды: eau женского рода, но перед гласной la сокращается до l’. S’il vous plaît — пожалуйста при вежливом обращении. L’addition — счёт в кафе.',
 [('Je voudrais un café.','Я хотел бы кофе.'), ('De l’eau, s’il vous plaît.','Воды, пожалуйста.'), ('L’addition, s’il vous plaît.','Счёт, пожалуйста.'), ('Merci beaucoup !','Большое спасибо!')],
 [('un café','кофе'),('de l’eau','воды'),('l’addition','счёт')],
 ('Ты закончил обед. Попроси счёт.',2), ('Je ___ un café.', 'voudrais', ['voudrait','voudront'])),
]
ZH = [
('你好 · первый контакт', 'Поздороваться, поблагодарить и попрощаться.',
 'Путунхуа записывается здесь упрощёнными иероглифами. Пиньинь показывает звучание: ā — ровный высокий тон, á — восходящий, ǎ — низкий с подъёмом, à — падающий. Без знака — лёгкий нейтральный тон. 你好 nǐ hǎo — привет; перед третьим тоном первый из двух звучит как второй (ní hǎo), но пишем nǐ hǎo. 谢谢 xièxie — спасибо.',
 [('你好！','Привет!','nǐ hǎo'), ('谢谢！','Спасибо!','xièxie'), ('不客气。','Не за что.','bú kèqi'), ('再见！','До свидания!','zàijiàn')],
 [('你好','привет','nǐ hǎo'),('谢谢','спасибо','xièxie'),('再见','до свидания','zàijiàn')],
 ('Орби: «谢谢！» Поблагодарили тебя. Ответь: не за что.',2), ('Привет: 你___！', '好', ['见','谢']), ['不','客气']),
('我叫 · имя', 'Представиться и узнать имя собеседника.',
 '我 wǒ — я, 你 nǐ — ты, 叫 jiào — зваться. 我叫安娜 — меня зовут Анна. Вопросительное 什么 shénme (что/какой) остаётся на месте ответа: 你叫什么名字？ Имя 安娜 читается Ānnà. 很高兴认识你 — приятно познакомиться; изучаем целиком как вежливую фразу.',
 [('我叫安娜。','Меня зовут Анна.','wǒ jiào Ānnà'), ('你叫什么名字？','Как тебя зовут?','nǐ jiào shénme míngzi'), ('我叫米科。','Меня зовут Мико.','wǒ jiào Mǐkē'), ('很高兴认识你。','Очень приятно познакомиться.','hěn gāoxìng rènshi nǐ')],
 [('我','я','wǒ'),('你','ты','nǐ'),('名字','имя','míngzi')],
 ('Орби спрашивает: «你叫什么名字？» Представься как Анна.',0), ('Меня зовут Анна: 我___安娜。', '叫', ['你','好']), ['我','叫','米科']),
('Числа и возраст', 'Посчитать до пяти и назвать возраст.',
 '一 yī, 二 èr, 三 sān, 四 sì, 五 wǔ — один, два, три, четыре, пять. 十 shí — десять; 二十 èrshí — двадцать. 岁 suì означает годы возраста. 我二十岁 — мне двадцать лет: глагол 是 здесь не нужен. 你多大？ — сколько тебе лет?',
 [('一、二、三。','Один, два, три.','yī, èr, sān'), ('四、五。','Четыре, пять.','sì, wǔ'), ('我二十岁。','Мне двадцать лет.','wǒ èrshí suì'), ('你多大？','Сколько тебе лет?','nǐ duō dà')],
 [('二','два','èr'),('三','три','sān'),('五','пять','wǔ')],
 ('Мико: «你多大？» Ответь: мне двадцать лет.',2), ('Возраст двадцать лет: 我二十___。', '岁', ['叫','你']), ['我','二十','岁']),
('Предметы · что это?', 'Узнать и назвать книгу и чашку.',
 '这 zhè — это (рядом), 是 shì — быть, 书 shū — книга, 杯子 bēizi — чашка. 这是什么？ — что это? 我有一本书 — у меня одна книга. Между числом и предметом нужен счётный знак: 本 běn для книг. 一 перед третьим тоном běn звучит yì: yì běn. Китайские слова не разделяются пробелами на письме.',
 [('这是书。','Это книга.','zhè shì shū'), ('这是杯子。','Это чашка.','zhè shì bēizi'), ('这是什么？','Что это?','zhè shì shénme'), ('我有一本书。','У меня одна книга.','wǒ yǒu yì běn shū')],
 [('书','книга','shū'),('杯子','чашка','bēizi'),('本','счётное слово для книг','běn')],
 ('Орби показывает книгу: «这是什么？» Назови предмет.',0), ('Одна книга: 一___书。', '本', ['岁','叫']), ['这','是','什么']),
('Моя семья', 'Представить маму, папу и старшую сестру.',
 '妈妈 māma — мама, 爸爸 bàba — папа: второй слог нейтральный. 姐姐 jiějie — именно старшая сестра; младшая называется иначе. 我的 wǒ de — мой/моя; 的 связывает владельца и предмет. С близкими 的 часто опускают, но здесь потренируем полную форму. 她 tā — она.',
 [('这是我的妈妈。','Это моя мама.','zhè shì wǒ de māma'), ('这是我的爸爸。','Это мой папа.','zhè shì wǒ de bàba'), ('这是我的姐姐。','Это моя старшая сестра.','zhè shì wǒ de jiějie'), ('她叫安娜。','Её зовут Анна.','tā jiào Ānnà')],
 [('妈妈','мама','māma'),('爸爸','папа','bàba'),('姐姐','старшая сестра','jiějie')],
 ('Мико спрашивает имя твоей старшей сестры. Скажи: её зовут Анна.',3), ('Это моя мама: 这是我___妈妈。', '的', ['是','岁']), ['这','是','我','的','姐姐']),
('В кафе · чай и просьбы', 'Попросить чай, воду и счёт.',
 '请 qǐng — пожалуйста (в просьбе), 给 gěi — дать. 请给我… — дайте мне…, пожалуйста. 一杯茶 yì bēi chá — чашка чая: 杯 — счётное слово для напитков в чашках, 茶 — чай. 一 перед первым тоном bēi звучит yì. 水 shuǐ — вода, 米饭 mǐfàn — варёный рис. 请结账 qǐng jiézhàng — счёт, пожалуйста.',
 [('请给我一杯茶。','Дайте мне чашку чая, пожалуйста.','qǐng gěi wǒ yì bēi chá'), ('请给我一杯水。','Дайте мне стакан воды, пожалуйста.','qǐng gěi wǒ yì bēi shuǐ'), ('我要米饭。','Я хочу рис.','wǒ yào mǐfàn'), ('请结账。','Счёт, пожалуйста.','qǐng jiézhàng')],
 [('茶','чай','chá'),('水','вода','shuǐ'),('米饭','варёный рис','mǐfàn')],
 ('Ты закончил обед. Вежливо попроси счёт.',3), ('Чашка чая: 一___茶。', '杯', ['本','岁']), ['我','要','米饭']),
]

def write(path, data):
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')

for lang, rows in [('fr',FR), ('zh',ZH)]:
    entries=[]
    for i,row in enumerate(rows):
        title, objective, guide, phrases, words, dialogue, gap, *chunks = row
        lid=f'{lang}-a1-{i+1:02}'
        vocab=[dict(id=f'{lang}:l{i+1}-w{j+1}', en=w[0],ru=w[1], **({'pronunciation':w[2]} if lang=='zh' else {})) for j,w in enumerate(words)]
        steps=[dict(character=['orbi','miko','zig_quartz','orbi'][j],title=['Встречаем фразу','Слушаем друга','Разбираемся вместе','Теперь твой ход'][j],phrase=p[0],translation=p[1],explanation=guide if j==2 else f'{p[0]} — {p[1]}',**({'pronunciation':p[2]} if lang=='zh' else {})) for j,p in enumerate(phrases)]
        # Vocabulary, grammar and *all* tested phrases are visible before recall.
        steps[0]['explanation'] += '\n' + '; '.join(' · '.join(w) for w in words)
        exercises=[]
        def ex(kind,prompt,answer,explanation,**kw):
            if 'options' in kw: kw['options']=list(dict.fromkeys(kw['options']))
            answers=[answer]
            if lang=='fr' and 'œ' in answer: answers.append(answer.replace('œ','oe'))
            exercises.append(dict(id=f'{lid}-e{len(exercises)+1:02}',type=kind,prompt=prompt,answers=answers,explanation=explanation,hint=guide,wordIds=[w['id'] for w in vocab],character=['orbi','miko','zig_quartz'][len(exercises)%3],phase='Практика' if len(exercises)<7 else 'Закрепление',**kw))
        a,b,c,d=phrases
        pron=lambda p: {'pronunciation':p[2]} if lang=='zh' else {}
        ex('choice',f'Выбери фразу: «{a[1]}»',a[0],f'{a[0]} — {a[1]}',options=[b[0],a[0],d[0]],**pron(a))
        ex('choice',f'Что означает «{b[0]}»?',b[1],f'{b[0]} — {b[1]}',options=[c[1],d[1],b[1]],**pron(b))
        answer=c[0].rstrip('.!?。！？')
        ex('order',f'Собери фразу: «{c[1]}»',answer,guide,tokens=chunks[0] if lang=='zh' else answer.split(),**pron(c))
        ex('pairs','Соедини слова и значения.', 'matched','; '.join(f'{w[0]} — {w[1]}' for w in words),pairs=vocab,**({'pronunciation':' · '.join(w[2] for w in words)} if lang=='zh' else {}))
        ex('listen','Послушай или открой текст и выбери значение.',d[1],f'{d[0]} — {d[1]}',audio=d[0],options=[a[1],d[1],c[1]],**pron(d))
        ex('gap',gap[0],gap[1],guide,options=[gap[2][0],gap[1],gap[2][1]])
        target=phrases[dialogue[1]]
        ex('dialogue',dialogue[0],target[0],f'{target[0]} — {target[1]}',options=[p[0] for p in phrases],scene=f'Орби: {dialogue[0]}\nМико: …',**pron(target))
        ex('choice',f'Найди перевод «{words[0][0]}».',words[0][1],guide,options=[w[1] for w in words],**({'pronunciation':words[0][2]} if lang=='zh' else {}))
        # New Mandarin learners use chunks/recognition; no unintroduced keyboard demand.
        ex('choice' if lang=='zh' else 'translate',f'Вспомни: «{d[1]}»',d[0],guide,**({'options':[p[0] for p in phrases]} if lang=='zh' else {}),**pron(d))
        ex('review',f'Финал разговора: {dialogue[0]}',target[0],f'Теперь ты умеешь: {objective.lower()}',options=[p[0] for p in reversed(phrases)],**pron(target))
        asset=f'assets/courses/{lid}.json'
        write(asset,dict(id=lid,title=title,topic=title,order=i,objective=objective,guide=guide,vocabulary=vocab,teachingSteps=steps,exercises=exercises))
        entries.append(dict(id=lid,title=title,asset=asset,order=i))
    write(f'assets/courses/manifest-{lang}.json',dict(id=f'ru-{lang}',version=1,sourceLanguage='ru',targetLanguage=lang,sections=[dict(id=f'{lang}-v012',title='Первые разговоры',themes=[dict(id=f'{lang}-intro',title='Начальный курс',lessons=entries)])]))
print('Authored 6 French + 6 Mandarin lessons, 120 exercises. Previous 40 unchanged.')
