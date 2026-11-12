"""Bind original picture vocabulary to evidence in the existing curriculum."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANGS = ['en', 'es', 'de', 'fr', 'zh']
VARIANTS = {
    ('de', 'house'): ['hause'], ('es', 'bag'): ['mochila'],
    ('en', 'apple'): ['apples'], ('es', 'apple'): ['manzanas'],
    ('de', 'apple'): ['äpfel'], ('fr', 'apple'): ['pommes'],
    ('fr', 'ticket'): ['billets'], ('es', 'ticket'): ['billetes'],
    ('es', 'key'): ['llaves'], ('fr', 'key'): ['clés', 'clefs'],
    ('en', 'rain'): ['raining'], ('zh', 'window'): ['窗'],
    ('zh', 'hotel'): ['旅馆'], ('zh', 'clock'): ['时钟'],
}
def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def bare(form):
    return re.sub(r"^(el |la |der |die |das |le |l')", '', form.lower())

corpora = {}
for lang in LANGS:
    manifest = read(ROOT / ('assets/courses/manifest' + ('' if lang == 'en' else '-' + lang) + '.json'))
    corpora[lang] = []
    for section in manifest['sections']:
        for theme in section['themes']:
            for entry in theme['lessons']:
                asset = ROOT / entry['asset']
                if entry['id'].startswith('a1-'):
                    asset = asset.parent / 'demo' / asset.name
                lesson = read(asset)
                text = ' '.join([s['phrase'] for s in lesson['teachingSteps']] +
                                [v['en'] for v in lesson['vocabulary']]).lower().replace('’', "'")
                corpora[lang].append((entry['id'], text, lesson['vocabulary']))

cards = []
for line in (ROOT / 'tool/picture_words.txt').read_text(encoding='utf-8').splitlines():
    if not line or line.startswith('#'):
        continue
    ident, meaning, *translations, pinyin = line.split('|')
    languages = {}
    for lang, forms in zip(LANGS, translations):
        forms = forms.split('/')
        terms = [bare(f) for f in forms] + VARIANTS.get((lang, ident), [])
        if (lang, ident) == ('zh', 'clock'):
            terms = ['时钟', '钟表']  # 分钟 means minutes, not a clock.
        def contains(text):
            return any(term in text if lang == 'zh' else re.search(r'\b' + re.escape(term) + r'\b', text) for term in terms)
        anchor = next(((lesson, words) for lesson, text, words in corpora[lang] if contains(text)), None)
        word_id = None
        if anchor:
            word_id = next((w['id'] for w in anchor[1] if bare(w['en']) in [bare(f) for f in forms]), None)
        languages[lang] = dict(forms=forms, lesson=anchor[0] if anchor else None, wordId=word_id)
        if lang == 'zh':
            languages[lang]['pinyin'] = pinyin.split('/')
    cards.append(dict(id=ident, meaning=meaning, languages=languages))
assert len(cards) == len({c['id'] for c in cards}) == 30
dest = ROOT / 'assets/learning'
dest.mkdir(exist_ok=True)
(dest / 'pictures.json').write_text(json.dumps(cards, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print({l: sum(bool(c['languages'][l]['lesson']) for c in cards) for l in LANGS})
