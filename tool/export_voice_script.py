"""Export original lesson lines for rights-cleared character recording sessions."""
import csv
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SPEAKERS = {"Орби": "orbi", "Мико": "miko", "Зиг": "zig_quartz", "Зиг Кварц": "zig_quartz", "Рэйво": "reyvo", "Астэр": "aster", "Веспа": "vespa", "Пикси": "pixie", "Нокс": "nox", "Профессор": "fox_scholar"}


def main():
    lines = {}

    def add(character, text, context):
        language = "ru-RU" if re.search("[А-Яа-яЁё]", text) else "en-US"
        lines.setdefault((character, language, text.strip()), context)

    for path in sorted((ROOT / "assets/courses/demo").glob("a1-*.json")):
        lesson = json.loads(path.read_text(encoding="utf-8"))
        for step in lesson.get("teachingSteps", []):
            add(step["character"], step["phrase"], f'{lesson["id"]}: {step["title"]}')
        for exercise in lesson["exercises"]:
            for field in ["success", "support", "recovered"]:
                if exercise.get("story", {}).get(field):
                    add(exercise["character"], exercise["story"][field], exercise["id"] + ": story response")
            if exercise.get("audio"):
                add(exercise["character"], exercise["audio"], exercise["id"])
            for line in exercise.get("scene", "").splitlines():
                speaker, sep, text = line.partition(":")
                if sep and speaker.strip() in SPEAKERS and text.strip() not in {"…", "...", ""}:
                    add(SPEAKERS[speaker.strip()], text, exercise["id"])
    for word in ["hello", "friend", "name", "from", "welcome", "goodbye"]:
        add("miko", word, "v07: personal practice")
    for character, phrases in {
        'miko': ['Hello!', 'My name is Miko.', 'My name is Orbi.', 'Goodbye!', 'book', 'two', 'one'],
        'zig_quartz': ['book', 'pen', 'bag'],
    }.items():
        for phrase in phrases:
            add(character, phrase, 'v09: Space Adventures')
    # Preserve every previously licensed recording and its exact text.
    old_manifest = ROOT / "assets/audio/voices/manifest.json"
    if old_manifest.exists():
        for entry in json.loads(old_manifest.read_text(encoding="utf-8"))["recordings"]:
            add(entry["character"], entry["text"], "previously shipped line")
    target = ROOT / "docs/audio/voice-script.tsv"
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t")
        writer.writerow(["character", "locale", "text", "context", "status"])
        for key, context in lines.items():
            writer.writerow([*key, context, "recording-required"])
    print(f"Exported {len(lines)} unique lines to {target}")


if __name__ == "__main__":
    main()
