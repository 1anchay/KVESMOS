"""Decode the shipped AAC files and verify their published hashes and signal.

Requires numpy and imageio-ffmpeg in the isolated voice authoring environment.
Does not download models or modify assets. Listening review is still required.
"""
import hashlib
import json
from pathlib import Path
import subprocess

import imageio_ffmpeg
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
checks = json.loads((ROOT / 'docs/audio/voice-pack-checksums.json').read_text())
manifest = json.loads((ROOT / 'assets/audio/voices/manifest.json').read_text())
durations = {}
for entry in checks['files']:
    path = ROOT / entry['asset']
    data = path.read_bytes()
    assert len(data) == entry['bytes'], path
    assert hashlib.sha256(data).hexdigest() == entry['sha256'], path
    decoded = subprocess.run([
        imageio_ffmpeg.get_ffmpeg_exe(), '-v', 'error', '-i', str(path),
        '-f', 'f32le', '-ac', '1', '-ar', '24000', 'pipe:1',
    ], check=True, capture_output=True)
    samples = np.frombuffer(decoded.stdout, dtype='<f4')
    assert len(samples) > 3600 and np.isfinite(samples).all(), path
    assert np.sqrt(np.mean(samples * samples)) > .001, path
    assert np.max(np.abs(samples)) < 1, path
    durations[entry['asset']] = len(samples) / 24000
for entry in manifest['recordings']:
    assert durations[entry['slowAsset']] > durations[entry['asset']], entry
print(json.dumps({'files': len(durations), 'lines': len(manifest['recordings']),
    'bytes': sum(e['bytes'] for e in checks['files']), 'hashesAndDecode': 'passed',
    'durationSeconds': [round(min(durations.values()), 2), round(max(durations.values()), 2)]}))
