"""Original KVESMOS earcons: deterministic additive synthesis, no downloaded audio."""
from pathlib import Path
import math
import struct
import wave

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets/audio/effects'
OUT.mkdir(parents=True, exist_ok=True)
SCORES = {
    'correct': [(660, .09), (880, .16)],
    'incorrect': [(330, .12), (294, .16)],
    'xp': [(988, .065), (1318, .12)],
    'complete': [(523, .10), (659, .10), (784, .10), (1047, .24)],
    'achievement': [(659, .08), (880, .08), (1175, .12), (1318, .23)],
    'chest': [(196, .07), (262, .08), (392, .12), (659, .20)],
    'rare': [(784, .09), (988, .09), (1175, .10), (1568, .25)],
    'tap': [(740, .045)],
}
RATE = 22050
for name, notes in SCORES.items():
    values = []
    for hz, seconds in notes:
        count = int(RATE * seconds)
        for i in range(count):
            t = i / RATE
            edge = min(1, t / .012, (seconds - t) / .035)
            envelope = max(0, edge) ** 2 * math.exp(-2.5 * t / seconds)
            tone = math.sin(2 * math.pi * hz * t) + .18 * math.sin(4 * math.pi * hz * t)
            values.append(int(15000 * envelope * tone))
        values.extend([0] * int(.012 * RATE))
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(struct.pack(f'<{len(values)}h', *values))
print('Prepared 8 original PCM earcons:', sum(p.stat().st_size for p in OUT.glob('*.wav')), 'bytes')
