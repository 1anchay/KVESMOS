"""Render offline English narration for Lost Signal or First Flight.

Uses the existing rights-cleared Kokoro authoring model. The model and engine
remain authoring dependencies and are not bundled in the application.
"""
import argparse
import hashlib
import importlib.metadata
import json
import subprocess
from pathlib import Path

import imageio_ffmpeg
import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

ROOT = Path(__file__).resolve().parents[1]
LOST_SIGNAL = [
    "We lost contact with Station Echo. Let’s go.",
    "Find the blue door.",
    "Find the red key and the battery.",
    "Do you have the battery?",
    "Put the battery in the power unit.",
    "Press the green button.",
    "Power is back. Signal restored!",
]
FIRST_FLIGHT = [
    "Door", "Key", "Battery", "Cable", "Light", "Button",
    "I need a battery.", "Press the button.",
]

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--model-dir", type=Path, required=True)
parser.add_argument("--rebuild", action="store_true")
parser.add_argument("--episode", choices=("lost-signal", "first-flight"), default="lost-signal")
args = parser.parse_args()
first_flight = args.episode == "first-flight"
character = "orbi" if first_flight else "miko"
voice = "am_puck" if first_flight else "am_michael"
texts = FIRST_FLIGHT if first_flight else LOST_SIGNAL

engine = Kokoro(
    str(args.model_dir / "kokoro-v1.0.onnx"),
    str(args.model_dir / "voices-v1.0.bin"),
)
manifest_path = ROOT / "assets/audio/voices/manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
entries = manifest["recordings"]
checks = []
for text in texts:
    ident = hashlib.sha256(f"{args.episode}|{character}|en-US|{text}".encode()).hexdigest()[:20]
    entry = {
        "character": character,
        "locale": "en-US",
        "text": text,
        "source": "synthetic",
        "performer": f"Kokoro v1.0 / {voice}",
        "redistributionApproved": True,
        "licenseAsset": "assets/audio/voices/licenses/KOKORO-NOTICE.txt",
    }
    for slow in (False, True):
        suffix = "-slow" if slow else ""
        path = ROOT / "assets/audio/voices/clips" / f"mission-{ident}{suffix}.m4a"
        if args.rebuild or not path.exists():
            samples, rate = engine.create(
                text,
                voice=voice,
                speed=.72 if slow else .94,
                lang="en-us",
            )
            samples = np.asarray(samples, dtype=np.float32)
            assert len(samples) / rate > .25 and np.isfinite(samples).all()
            peak = float(np.max(np.abs(samples)))
            if peak > .9:
                samples *= .9 / peak
            wav = args.model_dir / f"{args.episode}-current.wav"
            sf.write(wav, samples, rate, subtype="PCM_16")
            subprocess.run(
                [
                    imageio_ffmpeg.get_ffmpeg_exe(),
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-y",
                    "-i",
                    str(wav),
                    "-af",
                    "loudnorm=I=-19:TP=-3:LRA=7,alimiter=limit=0.8:level=false",
                    "-c:a",
                    "aac",
                    "-b:a",
                    "80k",
                    "-ac",
                    "1",
                    "-movflags",
                    "+faststart",
                    str(path),
                ],
                check=True,
            )
        entry["slowAsset" if slow else "asset"] = path.relative_to(ROOT).as_posix()
        checks.append(
            {
                "asset": path.relative_to(ROOT).as_posix(),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "bytes": path.stat().st_size,
                "text": text,
                "humanReviewed": False,
            }
        )
    entries = [
        value
        for value in entries
        if not (
            value["character"] == character
            and value["locale"] == "en-US"
            and value["text"] == text
        )
    ]
    entries.append(entry)

manifest["recordings"] = entries
manifest_path.write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
(ROOT / f"docs/audio/voice-{args.episode}-checksums.json").write_text(
    json.dumps(
        {
            "engine": importlib.metadata.version("kokoro-onnx"),
            "voice": voice,
            "files": checks,
        },
        ensure_ascii=False,
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)
