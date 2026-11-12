"""Original KVESMOS earcons: deterministic additive synthesis, no downloaded audio."""
from pathlib import Path
import math
import struct
import wave

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets/audio/effects'
OUT.mkdir(parents=True, exist_ok=True)
# Original five-note palette: warm fundamental, softly decaying harmonics.
# xp = every-third-answer streak; achievement = completed quest.
SCORES = {
 'interact': [(293.66, .04), (440, .06)],
 'pickup': [(587.33, .07), (880, .12)],
 'chapter': [(293.66, .10), (440, .12), (587.33, .14), (880, .26)],
 'equip': [(392, .055), (659.25, .13)],
 'epic': [(392, .08), (659.25, .09), (783.99, .11), (1046.5, .23)],
 'legendary': [(261.63, .09), (523.25, .10), (659.25, .11), (783.99, .12), (1046.5, .32)],
 'tap': [(440, .055)], 'correct': [(523.25, .10), (783.99, .18)],
 'incorrect': [(392, .12), (349.23, .18)],
 'xp': [(523.25, .08), (659.25, .09), (783.99, .19)],
 'complete': [(523.25, .10), (659.25, .10), (783.99, .12), (1046.5, .26)],
 'achievement': [(659.25, .10), (783.99, .10), (1046.5, .28)],
 'chest': [(261.63, .09), (392, .11), (659.25, .25)],
 'rare': [(523.25, .09), (783.99, .11), (1046.5, .28)],
}
RATE = 22050
report = {}
for name, notes in SCORES.items():
 values = []
 for hz, seconds in notes:
  for i in range(int(RATE * seconds)):
   t = i / RATE
   attack = .5 - .5*math.cos(math.pi*min(1, t/.012))
   release = .5 - .5*math.cos(math.pi*min(1, (seconds-t)/.045))
   envelope = attack * release * math.exp(-2*t/seconds)
   tone = math.sin(2*math.pi*hz*t) + .12*math.sin(2*math.pi*hz*2*t)*math.exp(-18*t)
   values.append(int(11000 * envelope * tone))
  values.extend([0] * int(.008*RATE))
 assert max(map(abs, values)) < 32767
 with wave.open(str(OUT / f'{name}.wav'), 'wb') as output:
  output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
  output.writeframes(struct.pack(f'<{len(values)}h', *values))
 report[name] = {'seconds': round(len(values)/RATE, 3), 'peak': round(max(map(abs,values))/32768, 3), 'rms': round((sum(v*v for v in values)/len(values))**.5/32768, 3)}
import json
print(json.dumps(report, indent=2))
