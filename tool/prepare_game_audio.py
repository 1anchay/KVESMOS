"""Generate original KVESMOS loops and earcons, with no third-party recordings."""
from pathlib import Path
import subprocess
import tempfile
import wave

import imageio_ffmpeg
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'
RATE = 32000
TAU = np.pi * 2

# Eight bars, two voicings of each progression. Note numbers are MIDI pitches.
SCORES = {
    'menu': (.67, [(50, 57, 60, 64), (46, 53, 57, 60), (48, 55, 59, 62), (45, 52, 55, 59)], (0, 2, 1, 3, 2, 1)),
    'ship': (.73, [(43, 50, 53, 57), (46, 53, 57, 60), (41, 48, 52, 55), (48, 55, 58, 62)], (1, 0, 2, 3, 1)),
    'exploration': (.59, [(45, 52, 55, 59), (48, 55, 59, 62), (41, 48, 52, 55), (43, 50, 53, 57)], (2, 1, 3, 0, 2, 1, 3)),
    'water': (.82, [(53, 60, 64, 67), (48, 55, 59, 64), (50, 57, 60, 64), (46, 53, 57, 60)], (1, 3, 2, 0, 3)),
}


def circular_add(target, at, values):
    count = len(target)
    start = round(RATE * at) % count
    split = min(count - start, len(values))
    target[start:start+split] += values[:split]
    target[:len(values)-split] += values[split:]


def tone(note, duration, soft=False):
    t = np.arange(round(duration * RATE)) / RATE
    hz = 440 * 2 ** ((note - 69) / 12)
    envelope = np.sin(np.pi * np.minimum(1, t / (.85 if soft else .035)) / 2) ** 2
    envelope *= np.sin(np.pi * np.minimum(1, (duration-t) / (.95 if soft else .27)) / 2) ** 2
    if not soft:
        envelope *= np.exp(-2.6 * t / duration)
    phase = TAU * hz * t
    return envelope * (np.sin(phase) + .19 * np.sin(2*phase + .12*np.sin(TAU*.45*t)) + .065*np.sin(3*phase))


def theme(beat, chords, melody):
    audio = np.zeros(round(RATE * beat * 32))
    for bar, chord in enumerate(chords * 2):
        start = bar * 4 * beat
        for voice, note in enumerate(chord):
            circular_add(audio, start + .036*voice, (.06 if voice else .10) * tone(note, beat*4.8, True))
        for i, step in enumerate(melody):
            when = start + (.34 + 3.45*i/len(melody)) * beat
            transposition = 12 if bar % 4 != 3 else 0
            notes = tone(chord[(step + (bar//4)) % 4] + transposition, beat*1.45)
            circular_add(audio, when, .08 * notes)
            circular_add(audio, when + beat*.57, .021 * notes)
    return audio


def atmosphere(water):
    rng = np.random.default_rng(81 if water else 19)
    n = RATE * 16
    spectrum = np.fft.rfft(rng.standard_normal(n))
    frequencies = np.fft.rfftfreq(n, 1/RATE)
    low, high = (35, 1300) if water else (21, 250)
    shaped = np.fft.irfft(spectrum * (1-np.exp(-(frequencies/low)**2)) * np.exp(-frequencies/high))
    t = np.arange(n) / RATE
    if water:
        surge = (.5+.5*np.sin(TAU*3*t/16))**2
        audio = shaped * (.075+.19*surge)
        for start in (3.1, 10.65):
            circular_add(audio, start, .027 * tone(79, .8))
            circular_add(audio, start+.26, .019 * tone(81, .55))
    else:
        audio = shaped * .115 + .044*np.sin(TAU*48*t) + .017*np.sin(TAU*72*t + .3*np.sin(TAU*t/16))
    return audio


EARCONS = {
    'token': [76], 'returnToken': [69], 'confirm': [64, 67], 'radio': [69, 74],
    'door': [45, 50], 'power': [45, 52, 60, 64], 'trust': [62, 69, 74],
    'location': [62, 67, 71, 76], 'cast': [62, 69], 'line': [56], 'bite': [66, 72],
    'tension': [53, 57], 'reel': [60], 'splash': [53, 60], 'catchFish': [62, 66, 69, 74],
    'escapeFish': [64, 59], 'recordFish': [62, 66, 69, 74, 78],
}


def write_wave(path, audio):
    pcm = (np.clip(audio, -.95, .95)*32767).astype('<i2')
    with wave.open(str(path), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(pcm.tobytes())


def main():
    (ROOT / 'game').mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='kvesmos-audio-') as work:
        source = Path(work) / 'source.wav'
        loops = {name: theme(*score) for name, score in SCORES.items()}
        loops.update(ship_room=atmosphere(False), water_shore=atmosphere(True))
        for name, audio in loops.items():
            write_wave(source, audio)
            subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-v', 'error', '-y', '-i', str(source),
                            '-c:a', 'libvorbis', '-q:a', '4', str(ROOT / 'game' / f'{name}.ogg')], check=True)
    for name, notes in EARCONS.items():
        audio = np.zeros(round(RATE * (.18+len(notes)*.092)))
        for i, pitch in enumerate(notes):
            circular_add(audio, i*.092, .19 * tone(pitch, .16))
        if name in {'cast', 'splash', 'radio', 'line'}:
            t = np.arange(len(audio))/RATE
            audio += .038*np.random.default_rng(len(notes)+51).standard_normal(len(t))*np.sin(np.pi*t/t[-1])**3
        write_wave(ROOT / 'effects' / f'{name}.wav', audio)


if __name__ == '__main__':
    main()
