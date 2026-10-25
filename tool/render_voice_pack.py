"""Build optional offline synthetic English speech, never a voice clone.

Run in an isolated authoring environment with kokoro-onnx, soundfile and
imageio-ffmpeg. Models stay outside the app. See docs/audio/KOKORO-PROVENANCE.md.
"""
import argparse
import csv
import hashlib
import importlib.metadata
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VOICES = {'orbi': 'af_heart', 'miko': 'am_michael', 'zig_quartz': 'am_puck'}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model-dir', type=Path, required=True)
    args = parser.parse_args()
    import numpy as np
    import soundfile as sf
    import imageio_ffmpeg
    from kokoro_onnx import Kokoro
    model = args.model_dir / 'kokoro-v1.0.onnx'
    voice_file = args.model_dir / 'voices-v1.0.bin'
    engine = Kokoro(str(model), str(voice_file))
    folder = ROOT/'assets/audio/voices/clips'
    folder.mkdir(parents=True, exist_ok=True)
    manifest, checks = [], []
    with (ROOT/'docs/audio/voice-script.tsv').open(encoding='utf-8') as f:
        lines=list(csv.DictReader(f, delimiter='\t'))
    for line in lines:
        if line['character'] not in VOICES or line['locale'] != 'en-US': continue
        voice=VOICES[line['character']]
        identifier=hashlib.sha256((line['character']+'|'+line['text']).encode()).hexdigest()[:16]
        entry={k:line[k] for k in ['character','locale','text']}
        entry.update(source='synthetic', performer=f'Kokoro v1.0 / {voice}', redistributionApproved=True, licenseAsset='assets/audio/voices/licenses/KOKORO-NOTICE.txt')
        for slow in [False,True]:
            target=folder/f'{identifier}{"-slow" if slow else ""}.m4a'
            if not target.exists():
                data,rate=engine.create(line['text'],voice=voice,speed=.78 if slow else .96,lang='en-us')
                data=np.asarray(data,dtype=np.float32)
                peak=float(np.max(np.abs(data)))
                if peak>.94: data *= .94/peak
                assert len(data)/rate>.15 and np.isfinite(data).all()
                assert float(np.sqrt(np.mean(data*data)))>.001
                wav=args.model_dir/'render-current.wav'
                sf.write(wav,data,rate,subtype='PCM_16')
                subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-loglevel','error','-y','-i',str(wav),'-c:a','aac','-b:a','80k','-ac','1','-movflags','+faststart',str(target)],check=True)
            entry['slowAsset' if slow else 'asset']=target.relative_to(ROOT).as_posix()
            checks.append({'asset':target.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'bytes':target.stat().st_size})
        manifest.append(entry)
        print(len(manifest),line['character'],line['text'],flush=True)
    (ROOT/'assets/audio/voices/manifest.json').write_text(json.dumps({'version':1,'recordings':manifest},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    evidence={'engine':importlib.metadata.version('kokoro-onnx'),'voices':VOICES,'modelSha256':hashlib.sha256(model.read_bytes()).hexdigest(),'voiceStylesSha256':hashlib.sha256(voice_file.read_bytes()).hexdigest(),'files':checks}
    (ROOT/'docs/audio/voice-pack-checksums.json').write_text(json.dumps(evidence,indent=2)+'\n',encoding='utf-8')
    print('Complete:',len(manifest),'lines',len(checks),'files',sum(c['bytes'] for c in checks),'bytes',flush=True)

if __name__=='__main__': main()
