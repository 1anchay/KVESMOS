"""Add offline English to the extended course using the existing licensed Kokoro voice.
Authoring environment only; model/engine are never included in the application.
"""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
import numpy as np
import soundfile as sf
import imageio_ffmpeg
from kokoro_onnx import Kokoro

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--model-dir', type=Path, required=True)
parser.add_argument('--rebuild', action='store_true')
args = parser.parse_args()
engine = Kokoro(str(args.model_dir/'kokoro-v1.0.onnx'), str(args.model_dir/'voices-v1.0.bin'))
texts = set()
for path in (ROOT/'assets/courses').glob('en-a1-*.json'):
    lesson = json.loads(path.read_text(encoding='utf-8'))
    texts.update(s['phrase'] for s in lesson['teachingSteps'])
    texts.update(w['en'] for w in lesson['vocabulary'])
    for e in lesson['exercises']:
        if e.get('audio'): texts.add(e['audio'])
        for line in e.get('scene','').splitlines():
            if ':' in line: texts.add(line.split(':',1)[1].strip())
texts = sorted(t for t in texts if t not in ('…','...','') and not re.search('[А-Яа-яЁё]',t))
entries, checks = [], []
for i,text in enumerate(texts):
    ident = hashlib.sha256(('en-US|v013|'+text).encode()).hexdigest()[:20]
    entry = dict(character='*',locale='en-US',courseId='ru-en',text=text,source='synthetic',performer='Kokoro v1.0 / am_michael',redistributionApproved=True,licenseAsset='assets/audio/voices/licenses/KOKORO-NOTICE.txt')
    for slow in [False,True]:
        path = ROOT/'assets/audio/voices/clips'/f'kokoro-{ident}{"-slow" if slow else ""}.m4a'
        if args.rebuild or not path.exists():
            data,rate = engine.create(text,voice='am_michael',speed=.70 if slow else .96,lang='en-us')
            data = np.asarray(data,dtype=np.float32)
            assert len(data)/rate>.15 and np.isfinite(data).all()
            assert float(np.sqrt(np.mean(data*data)))>.001
            peak=float(np.max(np.abs(data)))
            if peak>.90: data*=.90/peak
            wav = args.model_dir/'v013-current.wav'
            sf.write(wav,data,rate,subtype='PCM_16')
            subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-loglevel','error','-y','-i',str(wav),'-af','loudnorm=I=-19:TP=-3:LRA=7,alimiter=limit=0.8:level=false','-c:a','aac','-b:a','80k','-ac','1','-movflags','+faststart',str(path)],check=True)
        entry['slowAsset' if slow else 'asset'] = path.relative_to(ROOT).as_posix()
        checks.append(dict(asset=path.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),bytes=path.stat().st_size,text=text,humanReviewed=False))
    entries.append(entry)
    print(i+1,len(texts),text,flush=True)
manifest_path = ROOT/'assets/audio/voices/manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['recordings'] = [e for e in manifest['recordings'] if not (e['locale']=='en-US' and e['character']=='*')] + entries
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(ROOT/'docs/audio/voice-en-v014-checksums.json').write_text(json.dumps(dict(files=checks),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
