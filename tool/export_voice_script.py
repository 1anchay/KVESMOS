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
            if exercise.get("audio"):
                add(exercise["character"], exercise["audio"], exercise["id"])
            for line in exercise.get("scene", "").splitlines():
                speaker, sep, text = line.partition(":")
                if sep and speaker.strip() in SPEAKERS and text.strip() not in {"…", "...", ""}:
                    add(SPEAKERS[speaker.strip()], text, exercise["id"])
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
