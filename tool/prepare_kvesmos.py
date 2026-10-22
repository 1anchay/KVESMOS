"""Deterministic crops/resizes of the supplied v2 artwork. No generated artwork."""
from pathlib import Path
from PIL import Image, ImageOps
import json

source = Path('docs/design-handoff/01_approved')
dest = Path('assets/kvesmos')
dest.mkdir(parents=True, exist_ok=True)
provenance = {}

def export(name, relative, box=None, size=640):
    im = Image.open(source / relative).convert('RGBA')
    if box: im = im.crop(box)
    bbox = im.getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
    if bbox:
        x0,y0,x1,y1=bbox
        im = im.crop((max(0,x0-5),max(0,y0-5),min(im.width,x1+5),min(im.height,y1+5)))
    im.thumbnail((size, size), Image.Resampling.LANCZOS)
    im.save(dest / f'{name}.png', optimize=True)
    provenance[name] = {'source': relative, 'crop': box}
    return im

# Approved lower-right scene, not the other five mascot proposals.
logo = export('orbi_logo', 'orbi/orbi_icon_six_variants_original_sheet.png', (1204, 454, 1662, 858))
for emotion in ['happy', 'wink_thumbsup', 'surprised', 'thinking', 'pout', 'sleepy']:
    p = f'orbi/emotions/orbi_{emotion}.png'
    im = Image.open(source/p)
    top = {'thinking': 45, 'pout': 15, 'sleepy': 16, 'surprised': 20}.get(emotion, 0)
    export('orbi_'+emotion, p, (20 if emotion=='thinking' else 0, top, im.width, im.height))
export('pixie', 'characters/pixie_sheet.png')
# The supplied explorer and supernova filenames are reversed visually.
for kind, actual in [('explorer','supernova'), ('nebula','nebula'), ('supernova','explorer')]:
    for state in ['closed','open']:
        export(f'{kind}_{state}', f'chests/isolated/{actual}_{state}.png')

# Deliberate portrait windows; the complete concept sheets remain in the handoff.
portraits = {
 'miko': (0,0,380,410), 'aster': (0,0,390,420),
 'reyvo': (0,0,425,440), 'zig_quartz': (0,0,450,470),
 'vespa': (0,0,390,460), 'fox_scholar': (0,0,380,440),
 'nox': (0,0,430,500),
}
for name, box in portraits.items(): export(name, f'characters/{name}_sheet.png', box, 400)
sheet='cosmetics/cosmetics_20_items_concept_sheet.png'
rarities=['common','rare','epic','legendary']
for i,r in enumerate(rarities):
    x=[802,981,1160,1340][i]
    export('frame_'+r,sheet,(x,153,x+165,305),320)
    x=[29,227,427,631][i]
    export('background_'+r,sheet,(x,452,x+184,610),500)
    x=[859,1022,1186,1356][i]
    export('accessory_'+r,sheet,(x,449,x+150,584),320)

# Native icons use the same approved scene with an opaque navy safe border.
icon = Image.new('RGB',(1024,1024),'#0f172a')
art = ImageOps.contain(logo,(840,840),Image.Resampling.LANCZOS)
icon.paste(art,((1024-art.width)//2,(1024-art.height)//2),art)
icon.save(dest/'app_icon.png')
for density,pixels in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    icon.resize((pixels,pixels),Image.Resampling.LANCZOS).save(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
folder=Path('ios/Runner/Assets.xcassets/AppIcon.appiconset')
for entry in json.loads((folder/'Contents.json').read_text())['images']:
    pixels=round(float(entry['size'].split('x')[0])*float(entry['scale'][:-1]))
    icon.resize((pixels,pixels),Image.Resampling.LANCZOS).save(folder/entry['filename'])
(dest/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
catalog=json.loads(Path('docs/design-handoff/03_data/kv_catalog_draft_v2.json').read_text(encoding='utf-8'))
avatar=['miko','zig_quartz','reyvo','nox']
emote=['orbi_happy','orbi_surprised','orbi_wink_thumbsup','orbi_happy']
for c in catalog['cosmetics']:
    i=rarities.index(c['rarity']);slot=c['slot']
    name=avatar[i] if slot=='avatar' else emote[i] if slot=='emote' else f'{slot}_{rarities[i]}'
    c['asset_path']=f'assets/kvesmos/{name}.png'
    c['asset_status']='approved_derivative' if slot in ['avatar','emote'] else 'concept_crop'
    c['usable_with_characters']='profile_badge' if slot=='accessory' else 'profile'
for c in catalog['characters']:
    c['asset_path']=f"assets/kvesmos/{'orbi_logo' if c['id']=='orbi' else c['id']}.png"
catalog['status']='local_ui_v1'
(dest/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
