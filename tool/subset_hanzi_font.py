"""Subset OFL Noto Sans SC for course characters; platform fallback handles others.
Usage: python tool/subset_hanzi_font.py ORIGINAL.otf OFL.txt
Requires fonttools; does not touch approved illustration assets.
"""
import hashlib
import json
import sys
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont

source,license_path=map(Path,sys.argv[1:])
root=Path(__file__).resolve().parents[1]
texts='普通话你好我们一起学习。'
for p in (root/'assets/courses').glob('zh-a1-*.json'):
    texts+=p.read_text(encoding='utf-8')
codepoints={ord(c) for c in texts if '\u0020'<=c<='\u024f' or '\u0300'<=c<='\u036f' or '\u3400'<=c<='\u9fff' or '\u3000'<=c<='\u303f' or '\uff00'<=c<='\uffef'}
font=TTFont(source)
assert codepoints <= set(font.getBestCmap())
options=subset.Options(); options.name_IDs=['*']; options.name_legacy=True
builder=subset.Subsetter(options);builder.populate(unicodes=codepoints);builder.subset(font)
for record in font['name'].names:
    if record.nameID in [1,4,6,16]:
        record.string=('KVESMOS Hanzi' if record.nameID!=6 else 'KVESMOSHanzi').encode(record.getEncoding())
target=root/'assets/fonts/kvesmos-hanzi.otf';font.save(target)
(root/'assets/fonts/HANZI-OFL.txt').write_text('Subset of Noto Sans SC by Adobe and Google, renamed KVESMOS Hanzi.\nSource: https://github.com/notofonts/noto-cjk/tree/main/Sans/SubsetOTF/SC\nSubset only; original outlines retained.\n\n'+license_path.read_text(encoding='utf-8'),encoding='utf-8')
evidence=dict(sourceSha256=hashlib.sha256(source.read_bytes()).hexdigest(),subsetSha256=hashlib.sha256(target.read_bytes()).hexdigest(),characters=len(codepoints),bytes=target.stat().st_size)
(root/'docs/hanzi-font.json').write_text(json.dumps(evidence,indent=2)+'\n',encoding='utf-8')
print(evidence)
