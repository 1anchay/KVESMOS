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


def smooth(t):
    t = max(0, min(1, t))
    return t*t*(3-2*t)


def bake(name, pose, count, milliseconds):
    # All actions share the approved happy drawing and the same rest silhouette.
    # Local rigid rotation fields keep the mitten shape; only the sleeve blends.
    base, features, (hx, hy) = separate(pose)
    frames = []
    duration = count * milliseconds / 1000
    looping = name in {"hover", "talk"}
    for n in range(count):
        t = n / (count if looping else count-1)
        seconds = t * duration
        phase = math.tau * t
        envelope = math.sin(math.pi*t)**2
        blink = max(max(0, 1-abs(seconds-at)/.12) for at in (1.65, 4.9, 5.25))
        painted = base.copy()
        for index, (x,y,r,b), layer in features:
            openness = 1 - .97 * blink if index < 2 else 1
            if index < 2:
                if name == "support": openness *= 1-.25*envelope
                if name == "correct" and index == 1: openness *= 1-.92*envelope
                if name == "surprise": openness *= 1+.24*envelope
            if index == 2:
                if name == "talk":
                    openness = .25 + .75 * abs(math.sin(phase*5) * math.cos(phase*2))
                elif name == "support": openness = 1-.65*envelope
                elif name == "surprise": openness = 1+.3*envelope
            height = max(2, round(layer.height * openness))
            # Filter premultiplied RGBA to avoid dark/white fringes on feature edges.
            part = layer.convert("RGBa").resize((layer.width,height), Image.Resampling.LANCZOS).convert("RGBA")
            # Hold fixation, saccade, hold, then return; eyes do not perpetually swim.
            gaze = (smooth((t-.18)/.035)-smooth((t-.53)/.045))*2
            glance = round(gaze) if index < 2 else 0
            painted.alpha_composite(part,(x+glance,y+(b-y-height)//2))

        def deform(x,y,angle):
            hand_angle = (.18*math.sin(phase*3)*envelope if name == "greet" else
                          -.20*envelope if name == "correct" else
                          .22*math.sin(phase*2)*envelope if name == "celebrate" else
                          .12*envelope if name == "surprise" else
                          -.07*envelope if name == "support" else .025*math.sin(angle))
            # A rigid core and smooth sleeve falloff, instead of stretching the glove.
            radius = math.hypot((x-hx)/25, (y-hy)/25)
            influence = 1-smooth((radius-.65)/1.1)
            dx, dy = x-194, y-150
            a = hand_angle*influence
            rx = math.cos(a)*dx-math.sin(a)*dy-dx
            ry = math.sin(a)*dx+math.cos(a)*dy-dy
            left = weights(x,y,69,190,28,24)
            foot = weights(x,y,156,218,46,23)
            flight = envelope if name in {"flight","greet","celebrate","land"} else 0
            # Feet trail takeoff and settle after the body; opposing hand follows through.
            return (x+rx+left*1.8*math.sin(angle-.5)*envelope,
                    y+ry+foot*(4*flight*math.sin(angle-.5))+left*2*envelope)

        art = frame(painted.convert("RGBa"), phase, deform)
        canvas = Image.new("RGBA", (280,280))
        lift = (8*envelope if name in {"flight","greet","celebrate","land"}
                else 1.5*math.sin(phase) if looping else 2*envelope)
        canvas.alpha_composite(art,(10,round(10-lift)))
        art = canvas.convert("RGBa").resize((240,240),Image.Resampling.LANCZOS).convert("RGBA")
        frames.append(art)
    path = ART / "crew_motion" / f"orbi_visor_{name}.webp"
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=milliseconds,
                   loop=0 if looping else 1,quality=94,method=4)
    with Image.open(path) as result:
        assert result.n_frames == count
        for n in range(count):
            result.seek(n)
            assert result.convert("RGBA").getpixel((0,0))[3] == 0
    if name == "hover":
        frames[0].save(ART / "crew_motion/orbi_visor_rest.png")


if __name__ == "__main__":
    for name, spec in CONFIG["clips"].items():
        bake(name, *spec)
