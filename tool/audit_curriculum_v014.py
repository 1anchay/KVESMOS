"""Audit catalog integrity, teach/test references and additive v0.14 content."""
import json,re,hashlib,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def norm(s):return re.sub(r'[\s.,!?¿¡。！？，、;:«»]', '',s.lower().replace('’',"'"))
ids=set();exids=set();scenes=set();summary={};new_total=0
for lang,count in [('en',60),('es',30),('de',30),('fr',20),('zh',20)]:
 m=read(ROOT/('assets/courses/manifest.json' if lang=='en' else f'assets/courses/manifest-{lang}.json'))
 entries=[l for s in m['sections'] for t in s['themes'] for l in t['lessons']]
 assert len(entries)==count and [l['order'] for l in entries]==list(range(count))
 global_words=set()
 for item in entries:
  path=ROOT/item['asset'];payload=read(path)
  global_words.update(w['id'] for w in payload['vocabulary'])
  if item['id'].startswith('a1-'): global_words.update(w['id'] for w in read(ROOT/'assets/courses/demo'/path.name)['vocabulary'])
 exercises=0
 for info in entries:
  assert info['id'] not in ids;ids.add(info['id'])
  path=ROOT/info['asset']; j=read(path)
  if info['id'].startswith('a1-'):j=read(ROOT/'assets/courses/demo'/path.name)
  assert j['id']==info['id'] and j['order']==info['order']
  assert j['objective'] and j['guide'] and j['teachingSteps']
  assert 8<=len(j['exercises'])<=12
  assert len({e['type'] for e in j['exercises']})>=4
  known={w['id'] for w in j['vocabulary']};assert all(w.startswith(lang+':') for w in known)
  new='introActivities' in j
  if new:
   new_total+=1
   scene=next(e['scene'] for e in j['exercises'] if e.get('scene'))
   assert scene not in scenes;scenes.add(scene)
   assert len(j['introActivities']) in (2,3)
   for a in j['introActivities']:
    assert a['phrase'] in [p['phrase'] for p in j['teachingSteps']]
    assert a.get('options') or a.get('tokens')
    if a.get('options'):assert a['answer'] in a['options'] and len(set(a['options']))==len(a['options'])
    else:assert norm(' '.join(a['tokens']))==norm(a['answer'])
   assert any(e.get('recall') and e['type']=='translate' for e in j['exercises'])
  for e in j['exercises']:
   assert e['id'] not in exids;exids.add(e['id']);exercises+=1
   assert e['answers'] and all(e['answers']) and e['explanation']
   assert set(e.get('wordIds',[]))<=(known if new else global_words),(e['id'],'unknown word reference')
   if e.get('options'):
    assert len(set(e['options']))==len(e['options'])
    assert any(norm(a)==norm(o) for a in e['answers'] for o in e['options']),e['id']
   if e['type']=='order':assert any(norm(' '.join(e['tokens']))==norm(a) for a in e['answers']),e['id']
   if e['type']=='pairs':assert len({p['en'] for p in e['pairs']})==len(e['pairs'])
   if e.get('audio'):assert not re.search('[А-Яа-яЁё]',e['audio']),e['id']
   if new and e['type']=='translate':assert e['answers'][0] not in e['prompt'],e['id']
   if lang=='zh' and new and e['type'] in ('speak','translate'):
    assert e['pronunciation'] in e['answers']
  if lang=='zh':
   for p in j['teachingSteps']:
    assert p.get('pronunciation') and re.search('[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]',p['pronunciation']),j['id']
 summary[lang]={'lessons':count,'exercises':exercises}
assert new_total==60 and len(ids)==160
# The 100 original course pack payloads (plus 20 updated demo payloads) stay byte-equivalent under Git EOL normalization.
base='ee2a2a0b0a9164e0a6457da2a3e922934c90fe8e';unchanged=0
for lang in summary:
 manifest='assets/courses/manifest'+('' if lang=='en' else '-'+lang)+'.json'
 m=json.loads(subprocess.check_output(['git','show',base+':'+manifest],cwd=ROOT))
 paths=[l['asset'] for s in m['sections'] for t in s['themes'] for l in t['lessons']]
 if lang=='en':paths += [f'assets/courses/demo/a1-{i:02}.json' for i in range(1,21)]
 for p in paths:
  original=subprocess.check_output(['git','show',base+':'+p],cwd=ROOT).replace(b'\r\n',b'\n')
  assert (ROOT/p).read_bytes().replace(b'\r\n',b'\n')==original,p
  unchanged+=1
report={'courses':summary,'totalLessons':len(ids),'totalExercises':len(exids),'newLessons':new_total,'newDialogueScenes':len(scenes),'unchangedOldPayloads':unchanged,'externalNativeSpeakerReview':False}
(ROOT/'docs/curriculum-v014-audit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
