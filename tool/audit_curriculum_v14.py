"""Check the shipped lesson catalog and voice index without editing assets."""

import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COURSES = {"en": 100, "es": 60, "de": 60, "fr": 40, "zh": 40}
TONES = re.compile("[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]", re.I)
HANZI = re.compile("[\u3400-\u9fff]")


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8-sig"))


def normalize(text):
    text = text.lower().replace("’", "'").replace("ё", "е")
    for contraction, expanded in {
        "i'm": "i am", "it's": "it is", "that's": "that is", "he's": "he is",
        "she's": "she is", "we're": "we are", "you're": "you are",
    }.items():
        text = re.sub(rf"\b{contraction}\b", expanded, text)
    text = " ".join(re.sub(r"""[.,!?¿¡;:«»"—–。！？，、：；“”]""", " ", text).split())
    return text.replace(" ", "") if HANZI.search(text) and not re.search("[a-z]", text) else text


def audit():
    lessons, exercises, problems = set(), set(), []
    report = {}
    for lang, count in COURSES.items():
        suffix = "" if lang == "en" else f"-{lang}"
        manifest = read(f"assets/courses/manifest{suffix}.json")
        entries = [lesson for section in manifest["sections"]
                   for theme in section["themes"] for lesson in theme["lessons"]]
        assert manifest["sourceLanguage"] == "ru" and manifest["targetLanguage"] == lang
        assert [item["order"] for item in entries] == list(range(count))
        materials = []
        vocabulary = set()
        for info in entries:
            path = Path(info["asset"])
            original = read(path)
            current = read(path.parent / "demo" / path.name) if info["id"].startswith("a1-") else original
            materials.append((info, current))
            vocabulary.update(word["id"] for data in (original, current) for word in data["vocabulary"])
        totals = Counter()
        for info, lesson in materials:
            assert info["id"] == lesson["id"] and info["order"] == lesson["order"]
            assert lesson["id"] not in lessons
            lessons.add(lesson["id"])
            assert lesson["objective"] and lesson["guide"] and lesson["teachingSteps"]
            assert 8 <= len(lesson["exercises"]) <= 12
            assert len({row["type"] for row in lesson["exercises"]}) >= 4
            for step in lesson["teachingSteps"]:
                assert step["phrase"] and step["translation"]
                if lang == "zh":
                    assert HANZI.search(step["phrase"]) and TONES.search(step.get("pronunciation", "")), info["id"]
                totals["teachingSteps"] += 1
            for intro in lesson.get("introActivities", []):
                answers = [normalize(x) for x in intro.get("options", [])]
                if not answers:
                    answers = [normalize(" ".join(intro["tokens"]))]
                assert answers.count(normalize(intro["answer"])) == 1, info["id"]
                totals["interactiveIntroductions"] += 1
            for row in lesson["exercises"]:
                task = row["id"]
                assert task not in exercises
                exercises.add(task)
                answers = {normalize(answer) for answer in row["answers"]}
                assert answers and "" not in answers and row["explanation"] and row["prompt"], task
                assert set(row.get("wordIds", [])) <= vocabulary, task
                options = [normalize(option) for option in row.get("options", [])]
                if options and (len(set(options)) != len(options)
                                or sum(option in answers for option in options) != 1):
                    problems.append(f"{task}: expected one valid, distinct option")
                if row["type"] == "order":
                    assert normalize(" ".join(row["tokens"])) in answers, task
                if row["type"] == "pairs":
                    for field in ("en", "ru"):
                        assert len({normalize(pair[field]) for pair in row["pairs"]}) == len(row["pairs"]), task
                if row.get("audio"):
                    assert not re.search("[А-Яа-яЁё]", row["audio"]), task
                totals["exercises"] += 1
        report[lang] = {"lessons": count, **totals}

    recordings = read("assets/audio/voices/manifest.json")["recordings"]
    voices = Counter()
    for row in recordings:
        locale = row["locale"].split("-")[0]
        assert locale in {*COURSES, "ru"} and row["text"].strip()
        assert row["redistributionApproved"]
        fields = ("asset", "licenseAsset", "slowAsset") if row.get("slowAsset") else ("asset", "licenseAsset")
        for field in fields:
            assert (ROOT / row[field]).stat().st_size > 0, row[field]
        voices[locale] += 1
    assert not problems, "\n".join(problems)
    return {"lessons": len(lessons), "exercises": len(exercises), "courses": report,
            "recordings": dict(voices), "nativeSpeakerReview": False}


if __name__ == "__main__":
    print(json.dumps(audit(), ensure_ascii=False, indent=2))
