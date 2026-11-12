"""Compile original v0.15 editorial sources additively; never edit old packs."""
import argparse
import hashlib
import json
import re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
COUNTS = {'en': (60, 12), 'es': (30, 12), 'de': (30, 12), 'fr': (20, 12), 'zh': (20, 12)}
ZH_TOKENS = ['我/想/换/一件/大的', '我们/想/住/两晚', '她/已经/买票/了',
    '她/正在/打电话', '她/已经/做完/作业/了', '他/还没/回来', '我/坐过/高铁',
    '这间房/比/那间房/大', '电影/快要/开始/了', '请/先/看/菜单/再/点菜',
    '你/听懂/了/吗', '我/已经/尝过/北京烤鸭/了']
UNIT_TITLES = {
    'en':['Покупки и доставка','В дороге','Время и самочувствие','Опыт и результат','Уточнения и события','Просьбы и новости'],
    'es':['Покупки и бронирование','В гостях и дома','Прошлое: первые шаги','Поездки и события','Привычки и выбор','Просьбы и сообщения'],
    'de':['Покупки и бронирование','Приезд и помощь','Прошлое: Perfekt','Вопросы о прошлом','Вежливые действия','Мысли и новости'],
    'fr':['Покупки и бронирование','Номер и вещи','Прошлое с avoir','Движение и вопросы','Фон и сравнение','Причины и новости'],
    'zh':['Обмен и бронирование','Уже и сейчас','Завершение и ожидание','Опыт и сравнение','Скоро и по порядку','Результат и новости'],
}

def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,j): p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def norm(s): return re.sub(r'[\s.,!?¿¡。！？，、]', '', s.lower().replace('’', "'"))
def rows(lang):
    source=(ROOT/f'tool/curriculum_v015/{lang}.txt').read_text(encoding='utf-8-sig')
    result=[]
    for block in source.split('##')[1:]:
        lines=[s.strip() for s in block.strip().splitlines() if s.strip()]
        assert len(lines)==8, (lang, lines[0],len(lines))
        title,goal,guide=lines[0].split('|')
        phrases=[line.split('~') for line in lines[1:5]]
        dialogue=lines[5].split('~')
        question,*options=lines[6].split('|')
        repair=lines[7].split('~')
        assert len(options)==3 and len(set(options))==3
        assert len(repair)==3
        result.append(dict(title=title,goal=goal,guide=guide,phrases=phrases,
            dialogue=dialogue,question=question,options=options,repair=repair))
    assert len(result)==COUNTS[lang][1]
    return result

def build(lang):
    start,_=COUNTS[lang]
    previous=read(ROOT/f'assets/courses/{lang}-a1-{start:02}.json')
    lessons=[]
    for offset,row in enumerate(rows(lang)):
        number=start+offset+1; lid=f'{lang}-a1-{number:02}'
        ps=row['phrases']; a,b,c,d=ps
        assert len({p[0] for p in ps})==4
        assert all(len(p)==(3 if lang=='zh' else 2) for p in ps)
        tokens=ZH_TOKENS[offset].split('/') if lang=='zh' else b[0].split()
        assert norm(' '.join(tokens))==norm(b[0]),lid
        def pron(p): return {'pronunciation':p[2]} if lang=='zh' else {}
        vocab=[dict(id=f'{lang}:v015:{number}:p{i}',en=p[0],ru=p[1],**pron(p)) for i,p in enumerate(ps)]
        steps=[dict(character=['orbi','miko','zig_quartz','orbi'][i],title=row['title'],
                    phrase=p[0],translation=p[1],explanation=row['guide'] if i==0 else f'{p[0]} — {p[1]}',**pron(p))
               for i,p in enumerate(ps)]
        intros=[dict(id='recognize',phrase=a[0],translation=a[1],prompt='Выбери смысл реплики',
                     answer=a[1],options=[c[1],a[1],d[1]],explanation=row['guide'],**pron(a)),
                dict(id='apply',phrase=b[0],translation=b[1],prompt='Собери ответ по образцу',
                     answer=b[0],tokens=tokens,character='miko',explanation=f'{b[0]} — {b[1]}',**pron(b))]
        es=[]
        def ex(kind,prompt,answer,why,indices=(),**kw):
            answers=[answer]
            if lang=='zh' and kind in ('speak','translate'):
                answers.append(kw['pronunciation']);prompt+=' Можно ответить иероглифами или пиньинем с тонами.'
            es.append(dict(id=f'{lid}-e{len(es)+1:02}',type=kind,prompt=prompt,answers=answers,
                explanation=why,wordIds=[vocab[i]['id'] for i in indices],
                character=['orbi','miko','zig_quartz'][len(es)%3],
                phase='Понимаем' if len(es)<3 else 'Применяем',**kw))
        ex('choice',f'Как сказать: «{a[1]}»?',a[0],f'{a[0]} — {a[1]}',[0],
            options=[b[0],d[0],a[0]],hint=f'{a[0]} — {a[1]}',**pron(a))
        ex('order',f'Собери реплику: {b[1]}',b[0],row['guide'],[1],tokens=tokens,
            hint=f'{b[0]} — {b[1]}',**pron(b))
        scene='\n'.join(f'{speaker}: {line.strip()}' for speaker,line in zip(['Орби','Мико'],row['dialogue'][0].split(' / ')))
        ex('dialogue',row['question'],row['options'][0],'В диалоге: '+row['dialogue'][0]+' Поэтому: '+row['options'][0],
           range(4),scene=scene,options=[row['options'][1],row['options'][2],row['options'][0]],
           **({'scenePronunciation':row['dialogue'][1].replace(' / ','\n')} if lang=='zh' else {}))
        ex('listen','Послушай реплику и выбери её смысл. При необходимости открой текст.',
            c[1],f'{c[0]} — {c[1]}',[2],audio=c[0],options=[a[1],c[1],b[1]],
            hint=f'{c[0]} — {c[1]}',**pron(c))
        if offset%2==0:
            ex('pairs','Соедини реплики и их значения.','matched','Сопоставь каждую ситуацию с подходящей репликой.',range(4),pairs=vocab)
        ex('correct',f'Исправь одну ошибку: {row["repair"][0]}',row['repair'][1],row['repair'][2],
            options=[row['repair'][0],row['repair'][1]],hint=row['guide'])
        ex('speak',f'Передай собеседнику: «{d[1]}». Можно написать вместо микрофона.',d[0],
            f'{d[0]} — {d[1]}',[3],audio=d[0],recall=dict(phrase=d[0],meaning=d[1]),**pron(d))
        ex('translate',f'Вспомни реплику без вариантов: {a[1]}',a[0],row['guide'],[0],
            recall=dict(phrase=a[0],meaning=a[1]),**pron(a))
        old=previous['teachingSteps']; p=old[offset%len(old)]
        ex('review',f'Из прошлой темы: {p["translation"]}',p['phrase'],
            f'{p["phrase"]} — {p["translation"]}',options=list(dict.fromkeys(s['phrase'] for s in old)))
        # Conversation-first or listening-first arcs, followed by production.
        # Three arcs: conversation, listening, or recall of the prerequisite first.
        if offset%3==1:
            es[0],es[3]=es[3],es[0]
        elif offset%3==2:
            es.insert(0,es.pop())
        for i,e in enumerate(es):
            e['id']=f'{lid}-e{i+1:02}'
            e['phase']='Разогреваемся' if i==0 and e['type']=='review' else ('Понимаем' if i<3 else 'Применяем')
        lesson=dict(id=lid,title=row['title'],topic=UNIT_TITLES[lang][offset//2],order=number-1,
            objective=row['goal'],guide=row['guide'],vocabulary=vocab,teachingSteps=steps,
            introActivities=intros,exercises=es)
        lessons.append(lesson);previous=lesson
    return lessons

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--install',action='store_true');args=ap.parse_args()
    total=0
    for lang in COUNTS:
        lessons=build(lang);total+=len(lessons)
        dest=ROOT/('assets/courses' if args.install else 'test-output/curriculum-v015');dest.mkdir(parents=True,exist_ok=True)
        manifest_path=ROOT/('assets/courses/manifest.json' if lang=='en' else f'assets/courses/manifest-{lang}.json')
        m=read(manifest_path);old=[l for s in m['sections'] if s['id']!=f'{lang}-v015' for t in s['themes'] for l in t['lessons']]
        assert len(old)==COUNTS[lang][0]
        hashes={l['asset']:hashlib.sha256((ROOT/l['asset']).read_bytes()).hexdigest() for l in old}
        for lesson in lessons:write(dest/f'{lesson["id"]}.json',lesson)
        if args.install:
            section=dict(id=f'{lang}-v015',title='Самостоятельное общение',themes=[])
            for i in range(0,len(lessons),2):
                pair=lessons[i:i+2]
                section['themes'].append(dict(id=f'{lang}-v015-unit-{i//2+1}',title=UNIT_TITLES[lang][i//2],
                    lessons=[dict(id=l['id'],title=l['title'],asset=f'assets/courses/{l["id"]}.json',order=l['order']) for l in pair]))
            m['sections']=[s for s in m['sections'] if s['id']!=section['id']]+[section];write(manifest_path,m)
        assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
        print(lang,len(lessons),'lessons',sum(len(l['exercises']) for l in lessons),'exercises')
    assert total==60
if __name__=='__main__':main()
