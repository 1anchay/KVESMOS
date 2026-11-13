"""Compile the editorial sources for 1.3 without rewriting earlier lessons."""
import json
from pathlib import Path

from author_curriculum_v015 import build, COUNTS, UNIT_TITLES, ZH_TOKENS
import author_curriculum_v015 as compiler

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tool/curriculum_v13"
COUNTS.update(en=(72, 28), es=(42, 18), de=(42, 18), fr=(32, 8), zh=(32, 8))
UNIT_TITLES.update(zh=[
    "Время и дорога", "Предмет и результат", "Условия и выбор", "Новости и планы",
])
UNIT_TITLES["fr"] = [
    "Места и покупки", "Предметы и адреса", "Изменения и события", "Условия и новости",
]


def rows(lang):
    source = (SOURCES / f"{lang}.txt").read_text(encoding="utf-8-sig")
    result = []
    for block in source.split("##")[1:]:
        lines = block.strip().splitlines()
        title, goal, guide = lines[0].split("|")
        question, *options = lines[6].split("|")
        phrases = [line.split("~") for line in lines[1:5]]
        repair = lines[7].split("~")
        dialogue = lines[5].split("~")
        assert len(set(options)) == 3 and len(repair) == 3
        assert len(dialogue[0].split(" / ")) == 2
        if lang == "zh":
            assert len(lines) == 9 and all(len(p) == 3 for p in phrases)
            ZH_TOKENS.append(lines[8])
        else:
            assert len(lines) == 8 and all(len(p) == 2 for p in phrases)
        result.append(dict(title=title, goal=goal, guide=guide, phrases=phrases,
                           question=question, options=options, repair=repair, dialogue=dialogue))
    assert len(result) == COUNTS[lang][1]
    return result


def install(lang):
    manifest_path = ROOT / (
        "assets/courses/manifest.json" if lang == "en" else f"assets/courses/manifest-{lang}.json"
    )
    manifest = compiler.read(manifest_path)
    section_id = f"{lang}-v13"
    manifest["sections"] = [s for s in manifest["sections"] if s["id"] != section_id]
    assert sum(len(t["lessons"]) for s in manifest["sections"] for t in s["themes"]) == COUNTS[lang][0]
    if lang == "zh":
        ZH_TOKENS.clear()
    material = build(lang)
    section = dict(id=section_id, title="Разговоры и решения", themes=[])
    for offset in range(0, len(material), 2):
        theme = dict(id=f"{section_id}-{offset // 2 + 1}",
                     title=UNIT_TITLES[lang][offset // 2], lessons=[])
        for lesson in material[offset:offset + 2]:
            asset = f'assets/courses/{lesson["id"]}.json'
            old_prefix = f"{lang}:v015:{lesson['order'] + 1}:"
            new_prefix = f"{lang}:v13:{lesson['order'] + 1}:"
            raw = json.dumps(lesson, ensure_ascii=False, indent=2).replace(old_prefix, new_prefix)
            (ROOT / asset).write_text(raw + "\n", encoding="utf-8")
            theme["lessons"].append(dict(id=lesson["id"], title=lesson["title"],
                                         order=lesson["order"], asset=asset))
        section["themes"].append(theme)
    manifest["sections"].append(section)
    compiler.write(manifest_path, manifest)
    print(lang, len(material), sum(len(l["exercises"]) for l in material))


if __name__ == "__main__":
    import sys
    compiler.rows = rows
    for language in sys.argv[1:]:
        install(language)
