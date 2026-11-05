"""Compile authored lessons; preserve every previously shipped lesson byte.

Source rows are editorial material, not generated translations. New vocabulary
is taught before assessment. No source file is accepted without a dialogue,
comprehension distractors and an explained correction.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COUNTS = {'en': (28, 12), 'es': (6, 12), 'de': (6, 12), 'fr': (6, 6), 'zh': (6, 6)}


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def build(lang, rows):
    start, count = COUNTS[lang]
    assert len(rows) == count, (lang, len(rows))
    result = []
    phrases_seen = set()
    for offset, row in enumerate(rows):
        number = start + offset + 1
        lid = f'{lang}-a1-{number:02}'
        phrases = row['phrases']
        assert 3 <= len(phrases) <= 7
        assert len({p[0] for p in phrases}) == len(phrases)
        assert tuple(p[0] for p in phrases) not in phrases_seen
        phrases_seen.add(tuple(p[0] for p in phrases))
        assert row['goal'] and row['guide'] and row['dialogue'] and row['question']
        assert 2 <= len(row['dialogue'].splitlines()) <= 4
        assert len(set(row['comprehension'])) == 3
        assert len(row['repair']) == 3 and row['repair'][0] != row['repair'][1]
        vocab = [dict(id=f'{lang}:v013:{number}:p{i}', en=p[0], ru=p[1],
                      **({'pronunciation': p[2]} if lang == 'zh' else {}))
                 for i, p in enumerate(phrases)]
        if lang == 'zh':
            assert all(len(p) == 3 and p[2] for p in phrases)
        steps = [dict(character=['orbi', 'miko', 'zig_quartz', 'orbi'][i % 4],
                      title=['Новая ситуация', 'Ответ собеседнику', 'Замечаем правило', 'Применяем'][i % 4],
                      phrase=p[0], translation=p[1],
                      explanation=row['guide'] if i == 0 else f'{p[0]} — {p[1]}',
                      **({'pronunciation': p[2]} if lang == 'zh' else {}))
                 for i, p in enumerate(phrases)]
        # Explain the correction rule before asking the learner to apply it.
        steps[-1]['explanation'] += '\n' + row['repair'][2]
        exercises = []

        def ex(kind, prompt, answer, explanation, indices=(), **kw):
            exercises.append(dict(id=f'{lid}-e{len(exercises)+1:02}', type=kind,
                prompt=prompt, answers=[answer], explanation=explanation,
                hint=row['guide'], wordIds=[vocab[i]['id'] for i in indices],
                character=['orbi', 'miko', 'zig_quartz'][len(exercises) % 3],
                phase='Новая ситуация' if len(exercises) < 4 else 'Применяем в разговоре', **kw))

        a, b, c, d = phrases
        pron = lambda p: {'pronunciation': p[2]} if lang == 'zh' else {}
        ex('choice', f'Твоя задача: {a[1]} Выбери реплику.', a[0], f'{a[0]} — {a[1]}',
           [0], options=[c[0], a[0], b[0]], **pron(a))
        ex('listen', 'Радиосвязь: послушай Мико и выбери смысл. Текст можно открыть.',
           c[1], f'{c[0]} — {c[1]}', [2], audio=c[0], options=[b[1], d[1], c[1]], **pron(c))
        ex('order', f'Составь реплику: {b[1]}', b[0], row['guide'], [1],
           tokens=row['tokens'], **pron(b))
        ex('pairs', 'Соедини реплики с их значениями.', 'matched', row['guide'],
           range(4), pairs=vocab)
        ex('dialogue', row['question'], row['comprehension'][0],
           row['dialogue'] + '\n' + row['comprehension'][0],
           range(4), scene=row['dialogue'],
           options=[row['comprehension'][1], row['comprehension'][0], row['comprehension'][2]])
        ex('correct', f'Исправь одну ошибку: {row["repair"][0]}', row['repair'][1],
           row['repair'][2], options=[row['repair'][0], row['repair'][1]])
        ex('speak', f'Произнеси реплику или введи её текстом: {d[1]}', d[0],
           f'{d[0]} — {d[1]}', [3], audio=d[0], **pron(d))
        ex('translate', f'Вспомни без вариантов: {a[1]}', a[0], row['guide'], [0], **pron(a))
        ex('choice', f'Что означает реплика «{b[0]}»?', b[1], f'{b[0]} — {b[1]}',
           [1], options=[a[1], b[1], d[1]], **pron(b))
        ex('review', f'Заверши тренировку: {d[1]}', d[0],
           'Теперь ты умеешь: ' + row['goal'], [3], options=[a[0], c[0], d[0]], **pron(d))
        result.append(dict(id=lid, title=row['title'], topic=row['title'],
            order=number-1, objective=row['goal'], guide=row['guide'],
            vocabulary=vocab, teachingSteps=steps, exercises=exercises))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--language', choices=list(COUNTS), action='append')
    parser.add_argument('--install', action='store_true', help='Publish additive course packs and manifests')
    args = parser.parse_args()
    for lang in args.language or COUNTS:
        lessons = build(lang, read(ROOT / f'tool/curriculum_v013/{lang}.json'))
        dest = ROOT / ('assets/courses' if args.install else 'test-output/curriculum-v013')
        dest.mkdir(parents=True, exist_ok=True)
        for lesson in lessons:
            write(dest / (lesson['id'] + '.json'), lesson)
        if args.install:
            path = ROOT / ('assets/courses/manifest.json' if lang == 'en' else f'assets/courses/manifest-{lang}.json')
            manifest = read(path)
            old = [l for s in manifest['sections'] if s['id'] != f'{lang}-v013'
                   for t in s['themes'] for l in t['lessons']]
            assert len(old) == COUNTS[lang][0]
            before = {l['asset']: hashlib.sha256((ROOT/l['asset']).read_bytes()).hexdigest() for l in old}
            section = dict(id=f'{lang}-v013', title='Самостоятельные разговоры', themes=[])
            for i in range(0, len(lessons), 2):
                pair = lessons[i:i+2]
                section['themes'].append(dict(id=f'{lang}-v013-unit-{i//2+1}',
                    title=pair[0]['title'], lessons=[dict(id=l['id'], title=l['title'],
                    asset=f'assets/courses/{l["id"]}.json', order=l['order']) for l in pair]))
            manifest['sections'] = [s for s in manifest['sections'] if s['id'] != section['id']] + [section]
            write(path, manifest)
            assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest() == digest for p, digest in before.items())
        print(f'{lang}: {len(lessons)} authored lessons, {sum(len(l["exercises"]) for l in lessons)} exercises; installed={args.install}')


if __name__ == '__main__':
    main()
