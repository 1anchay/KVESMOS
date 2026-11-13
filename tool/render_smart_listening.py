"""Render only new KVESMOS listening lines using the existing licensed models.

Run from the repo with the Kokoro environment for en, Piper for es/de/fr:
    python tool/render_smart_listening.py en
    python tool/render_smart_listening.py es de fr
Mandarin uses an installed Android voice. No model is bundled.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import wave

import imageio_ffmpeg
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
VOICES = ROOT / "assets/audio/voices"
MODELS = ROOT / ".tools"
PIPER = {
    "es": ("es-ES", "es_ES-sharvard-medium", "PIPER-V012-NOTICE.txt"),
    "de": ("de-DE", "de_DE-thorsten-medium", "PIPER-V012-NOTICE.txt"),
    "fr": ("fr-FR", "fr_FR-siwis-medium", "PIPER-V013-NOTICE.txt"),
}


def render(language, texts, entries):
    if language == "en":
        from kokoro_onnx import Kokoro

        model = MODELS / "kokoro"
        engine = Kokoro(str(model / "kokoro-v1.0.onnx"), str(model / "voices-v1.0.bin"))
        locale = "en-US"
        performer = "Kokoro v1.0 / am_michael"
        license_name = "KOKORO-NOTICE.txt"

        def synthesize(text):
            return engine.create(text, voice="am_michael", speed=.96, lang="en-us")
    else:
        from piper import PiperVoice, SynthesisConfig

        locale, model_name, license_name = PIPER[language]
        engine = PiperVoice.load(str(MODELS / "piper-models" / f"{model_name}.onnx"))
        performer = f"Piper / {model_name} / speaker 0"

        def synthesize(text):
            chunks = list(engine.synthesize(
                text, SynthesisConfig(speaker_id=0 if language == "es" else None),
            ))
            return np.concatenate([c.audio_float_array for c in chunks]), chunks[0].sample_rate

    for text in sorted(texts):
        if any(row["locale"] == locale and row["text"] == text for row in entries):
            continue
        ident = hashlib.sha256(f"{locale}|{text}".encode()).hexdigest()[:16]
        path = VOICES / "clips" / f"smart-{ident}.m4a"
        data, rate = synthesize(text)
        assert len(data) / rate > .2 and np.isfinite(data).all()
        assert float(np.sqrt(np.mean(data * data))) > .001
        with tempfile.TemporaryDirectory() as temp:
            wav = Path(temp) / "speech.wav"
            with wave.open(str(wav), "wb") as output:
                output.setparams((1, 2, rate, 0, "NONE", "not compressed"))
                output.writeframes((np.clip(data, -.95, .95) * 32767).astype("<i2").tobytes())
            subprocess.run([
                imageio_ffmpeg.get_ffmpeg_exe(), "-hide_banner", "-loglevel", "error",
                "-y", "-i", str(wav), "-af", "loudnorm=I=-19:TP=-3:LRA=7",
                "-c:a", "aac", "-b:a", "64k", "-ac", "1", "-movflags", "+faststart",
                str(path),
            ], check=True)
        entries.append(dict(
            character="*", locale=locale, courseId=f"ru-{language}", text=text,
            source="synthetic", performer=performer, redistributionApproved=True,
            licenseAsset=f"assets/audio/voices/licenses/{license_name}",
            asset=path.relative_to(ROOT).as_posix(),
        ))


def main():
    source = (ROOT / "assets/learning/listening.txt").read_text(encoding="utf-8")
    manifest_path = VOICES / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for language in sys.argv[1:]:
        texts = {
            row.split("|")[1]
            for block in source.split("##")[1:] if block.startswith(language + "|")
            for row in block.splitlines()[1:]
            if row.split("|")[0] in ("orbi", "miko", "zig_quartz")
        }
        render(language, texts, manifest["recordings"])
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8",
    )


if __name__ == "__main__":
    main()
