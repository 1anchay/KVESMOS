"""Bake Orbi's visor layers and hand controls from the approved painted poses."""
import json
import math
from pathlib import Path
import cv2
import numpy as np
from PIL import Image
from bake_crew_idle import frame, weights

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/kvesmos"
CONFIG = json.loads((ROOT / "docs/design-handoff/04_sources/orbi-visor/rig.json").read_text(encoding="utf-8-sig"))


def separate(pose):
    rig = CONFIG["poses"][pose]
    base = Image.open(ART / f"orbi_{pose}.png").convert("RGBA")
    base.thumbnail((CONFIG["width"], CONFIG["width"]), Image.Resampling.LANCZOS)
    pixels = np.array(base)
    removal = np.zeros(pixels.shape[:2], dtype=np.uint8)
    features = []
    for index, box in enumerate([*rig["eyes"], rig["mouth"]]):
        if box is None:
            continue
        x, y, r, b = box
        rgb = pixels[y:b, x:r, :3].astype(int)
        red, green, blue = rgb.transpose(2, 0, 1)
        mask = ((blue > red + 36) & (green > red + 32) & (green > 65)
                if index < 2 else (red > green + 35) & (red > 75))
        contours, _ = cv2.findContours(mask.astype("uint8"), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not contours:
            raise ValueError(f"{pose}: empty feature {index}")
        alpha = np.zeros(mask.shape, dtype=np.uint8)
        cv2.drawContours(alpha, contours, -1, 255, cv2.FILLED)
        alpha = cv2.dilate(alpha, np.ones((3, 3), np.uint8))
        removal[y:b, x:r] |= alpha
        layer = base.crop(box)
        layer.putalpha(Image.fromarray(alpha))
        features.append((index, box, layer))
    pixels[:, :, :3] = cv2.inpaint(pixels[:, :, :3].copy(), removal, 3, cv2.INPAINT_TELEA)
    return Image.fromarray(pixels), features, rig["hand"]


def bake(name, pose, count, milliseconds):
    base, features, (hx, hy) = separate(pose)
    frames = []
    for n in range(count):
        t = n / count
        phase = math.tau * t
        # Blink spans four to six drawings with a shorter closing stroke.
        blink = max(0, 1 - abs(t - .64) / .065)
        gesture = math.sin(math.pi*t)**2
        painted = base.copy()
        for index, (x,y,r,b), layer in features:
            openness = 1 - .89 * blink if index < 2 else 1
            if index == 2 and name == "talk":
                openness = .32 + .68 * abs(math.sin(phase*2) * math.cos(phase))
            height = max(2, round(layer.height * openness))
            part = layer.resize((layer.width,height), Image.Resampling.LANCZOS)
            glance = round(1.6 * math.sin(phase)) if index < 2 else 0
            painted.alpha_composite(part,(x+glance,y+(b-y-height)//2))

        def deform(x,y,angle):
            wrist = weights(x,y,hx,hy,32,30)
            head = weights(x,y,122,106,100,72)
            foot = weights(x,y,156,207,70,28)
            wave = math.sin(angle)
            hand = (8 * gesture if name == "correct" else
                    6 * math.sin(angle*2)*gesture if name == "greet" else
                    3 * wave)
            thrust = 6 if name == "flight" else 2
            return (x - hand*wrist - wave*head,
                    y + hand*wrist + wave*head - thrust*foot*math.sin(angle+.4))

        art = frame(painted.convert("RGBa"), phase, deform)
        art.thumbnail((216,216),Image.Resampling.LANCZOS)
        frames.append(art)
    path = ART / "crew_motion" / f"orbi_visor_{name}.webp"
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=milliseconds,
                   loop=1 if name in {"greet","correct","surprise"} else 0,quality=91,method=4)
    with Image.open(path) as result:
        assert result.n_frames == count
        for n in range(count):
            result.seek(n)
            assert result.convert("RGBA").getpixel((0,0))[3] == 0


if __name__ == "__main__":
    for name, spec in CONFIG["clips"].items():
        bake(name, *spec)
