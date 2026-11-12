"""Offline authoring only: Piper ES/DE/FR, original course text, two speeds.

Install piper-tts==1.8.0 and imageio-ffmpeg in an isolated environment.
Download the models listed in docs/audio/PIPER-V012.md outside app assets.
No service calls, model weights or synthesis engine are included in the APK.
"""
import argparse
import hashlib
import json
import re
import subprocess
import struct
import wave
from pathlib import Path
import numpy as np
import imageio_ffmpeg
from piper import PiperVoice, SynthesisConfig

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--model-dir', type=Path, required=True)
args = parser.parse_args()
manifest_path = ROOT/'assets/audio/voices/manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['recordings'] = [r for r in manifest['recordings'] if r['locale'] not in ['es-ES','de-DE','fr-FR']]
checks, stats = [], {}
def duration(path):
    data=path.read_bytes()
    # ffmpeg's faststart AAC container uses mdhd v0, before the audio payload.
    pos=data.index(b'mdhd')
    assert data[pos+4] == 0
    scale,length=struct.unpack_from('>II',data,pos+16)
    return length/scale
for lang, model in [('es','es_ES-sharvard-medium'),('de','de_DE-thorsten-medium'),('fr','fr_FR-siwis-medium')]:
    texts=set()
    for file in sorted((ROOT/'assets/courses').glob(f'{lang}-a1-*.json')):
        lesson=json.loads(file.read_text(encoding='utf-8'))
        texts.update(s['phrase'] for s in lesson['teachingSteps'])
        texts.update(w['en'] for w in lesson['vocabulary'])
        for e in lesson['exercises']:
            if e.get('audio'): texts.add(e['audio'])
            if e.get('scene'):
                texts.update(line.split(':',1)[-1].strip() for line in e['scene'].splitlines() if ':' in line and line.split(':',1)[-1].strip() not in ('…','...'))
            if e['type'] in ['dialogue','review']:
                texts.update(re.findall('«([^»]+)»',e['prompt']))
                texts.update(e['answers'])
    texts=sorted(t for t in texts if not re.search('[А-Яа-яЁё]',t))
    model_path=args.model_dir/(model+'.onnx')
    engine=PiperVoice.load(str(model_path))
    assert engine.config.espeak_voice.startswith(lang), engine.config.espeak_voice
    locale={'es':'es-ES','de':'de-DE','fr':'fr-FR'}[lang]
    for i,text in enumerate(texts):
        ident=hashlib.sha256((locale+'|'+text).encode()).hexdigest()[:20]
        entry=dict(character='*',locale=locale,courseId=f'ru-{lang}',text=text,source='synthetic',performer=f'Piper / {model} / speaker 0',redistributionApproved=True,licenseAsset='assets/audio/voices/licenses/PIPER-V013-NOTICE.txt' if lang=='fr' else 'assets/audio/voices/licenses/PIPER-V012-NOTICE.txt')
        for slow in [False,True]:
            target=ROOT/'assets/audio/voices/clips'/f'piper-{ident}{"-slow" if slow else ""}.m4a'
            wav=args.model_dir/'current.wav'
            phonemes=engine.phonemize(text)
            if not target.exists():
                chunks=list(engine.synthesize(text,SynthesisConfig(speaker_id=0 if lang=='es' else None,length_scale=1.30 if slow else 1.0,normalize_audio=True)))
                data=np.concatenate([c.audio_float_array for c in chunks])
                rate=chunks[0].sample_rate
                assert np.isfinite(data).all() and len(data)/rate>.12 and np.sqrt(np.mean(data*data))>.001, text
                peak=float(np.max(np.abs(data)))
                if peak>.94: data*=.94/peak
                with wave.open(str(wav),'wb') as out:
                    out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate);out.writeframes((data*32767).astype(np.int16).tobytes())
                subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-loglevel','error','-y','-i',str(wav),'-af','loudnorm=I=-19:TP=-2:LRA=7','-c:a','aac','-b:a','80k','-ar','22050','-ac','1','-movflags','+faststart',str(target)],check=True)
            asset=target.relative_to(ROOT).as_posix()
            entry['slowAsset' if slow else 'asset']=asset
            if slow:
                normal_duration=duration(ROOT/entry['asset'])
                slow_duration=duration(target)
                if slow_duration < normal_duration*1.15:
                    # Stochastic synthesis of very short words can be unexpectedly
                    # short. Guarantee a genuinely slower, pitch-preserving clip.
                    temporary=args.model_dir/'slower.m4a'
                    rate=slow_duration/(normal_duration*1.30)
                    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-loglevel','error','-y','-i',str(target),'-af',f'atempo={rate:.6f}','-c:a','aac','-b:a','80k','-movflags','+faststart',str(temporary)],check=True)
                    target.write_bytes(temporary.read_bytes())
            checks.append(dict(asset=asset,sha256=hashlib.sha256(target.read_bytes()).hexdigest(),bytes=target.stat().st_size,text=text,locale=locale,slow=slow,phonemes=phonemes,humanReviewed=False))
        manifest['recordings'].append(entry)
        print(lang,i+1,'/',len(texts),text,flush=True)
    stats[locale]=dict(phrases=len(texts),files=len(texts)*2,model=model,modelSha256=hashlib.sha256(model_path.read_bytes()).hexdigest(),configSha256=hashlib.sha256(Path(str(model_path)+'.json').read_bytes()).hexdigest())
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(ROOT/'docs/audio/voice-v013-checksums.json').write_text(json.dumps(dict(engine='piper-tts 1.8.0',voices=stats,files=checks),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(stats),flush=True)
