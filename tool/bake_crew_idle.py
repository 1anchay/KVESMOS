"""Bake the crew idle loops from the approved transparent figures.

A rest-space mesh follows the painted silhouette. Feet anchor the lower body;
the chest expands, the head settles and the projected map floats above the palm.
Miko uses pixels of the 345 x 448 source. Other figures use normalized controls.
"""
from pathlib import Path
import math
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets/kvesmos/crew_motion"


def weights(x, y, cx, cy, rx, ry):
    return math.exp(-((x - cx) / rx) ** 2 - ((y - cy) / ry) ** 2)


def rest_point(x, y, phase):
    breath = math.sin(phase)
    turn = math.sin(phase + 0.42)
    head = weights(x, y, 110, 116, 108, 97)
    chest = weights(x, y, 115, 229, 94, 65)
    wrist = weights(x, y, 260, 174, 54, 43)
    map_light = weights(x, y, 287, 73, 68, 70)
    dx = 2.4 * turn * head + (x - 115) * .023 * chest * breath
    dy = -2.8 * breath * chest - 2 * breath * head
    dy += 3.6 * turn * wrist + 5 * math.sin(phase - .55) * map_light
    return x - dx, y - dy


def frame(source, phase, deformation=rest_point):
    mesh = []
    for y in range(0, source.height, 12):
        for x in range(0, source.width, 12):
            r, b = min(x + 12, source.width), min(y + 12, source.height)
            corners = ((x, y), (x, b), (r, b), (r, y))
            quad = tuple(v for i, j in corners for v in deformation(i, j, phase))
            mesh.append(((x, y, r, b), quad))
    return source.transform(source.size, Image.Transform.MESH, mesh,
                            Image.Resampling.BICUBIC).convert("RGBA")


if __name__ == "__main__":
    source = Image.open(ROOT / "miko_bridge.webp").convert("RGBa")
    assert source.size == (345, 448), "Recalibrate mesh to the new source"
    frames = [frame(source, math.tau * n / 40) for n in range(40)]
    frames = [f.resize((173, 224), Image.Resampling.LANCZOS) for f in frames]
    frames[0].save(ROOT / "miko_bridge_idle.webp", save_all=True,
                   append_images=frames[1:], duration=80, loop=0,
                   quality=90, method=4, minimize_size=True)


# Rest-space controls (center, influence radius, displacement, phase offset).
# Units are fractions of the trimmed source dimensions. Staggered phases
# give loose props and extremities a follow-through independent of the torso.
CREW = {
    # Orbital brim, raised mitten, lower boot
    "orbi": (3200, [(0.44,.29,.44,.18,.013,-.018,0),(.82,.47,.15,.15,.014,-.031,.8),(.57,.86,.18,.14,-.015,.018,1.3)]),
    # Goggles and antennae, raised wrench, relaxed hand
    "zig_quartz": (2880, [(.57,.12,.43,.16,.033,.012,.8),(.90,.47,.14,.20,-.012,-.023,0),(.20,.60,.15,.18,.014,.009,1.5)]),
    # Floating antenna, opposite hand and trailing bag
    "pixie": (3040, [(.68,.13,.30,.17,-.037,.019,0),(.83,.62,.22,.15,.028,-.020,.75),(.18,.70,.22,.21,.024,.017,1.7),(.49,.88,.16,.12,-.025,.025,2.1)]),
    # Projector, guiding wrist and scarf
    "aster": (3600, [(.82,.28,.19,.17,.020,-.025,1),(.73,.48,.18,.13,.008,-.016,.3),(.26,.62,.24,.20,-.016,.010,1.8)]),
    # Fin crest, pointing arm and flame tail
    "reyvo": (2560, [(.60,.14,.28,.13,-.018,.008,.5),(.20,.42,.19,.13,.021,-.015,0),(.17,.67,.19,.17,-.031,-.022,1.1)]),
    # Butterfly, wrist and flowing sash
    "vespa": (3840, [(.22,.25,.15,.13,-.022,-.020,1),(.25,.35,.18,.10,.012,-.016,.4),(.20,.62,.20,.21,.028,.012,1.7)]),
    # Stellar halo and two independently trailing folds of the cloak
    "nox": (4160, [(.60,.09,.34,.10,.028,-.008,.7),(.25,.65,.22,.27,-.030,.008,.3),(.67,.88,.27,.15,.026,-.012,1.5)]),
    # Listening ears, head inclining and bushy tail
    "fox_scholar": (3520, [(.48,.12,.29,.10,.016,-.008,.4),(.54,.23,.23,.14,.013,.009,0),(.20,.69,.21,.19,-.032,-.012,1.3)]),
}


def export_crew(name, duration, controls):
    base = ROOT.parent
    path = base / "orbi_happy.png" if name == "orbi" else (
        base / "pixie.png" if name == "pixie" else ROOT / f"{name}_bridge.webp")
    source = Image.open(path).convert("RGBA")
    source = source.crop(source.getbbox())
    source.thumbnail((224, 224), Image.Resampling.LANCZOS)
    # Leave a gutter so moving extremities stay inside the exported frame.
    canvas = Image.new("RGBA", (source.width + 16, source.height + 16))
    canvas.paste(source, (8, 8))
    source = canvas.convert("RGBa")
    w, h = source.size

    def deform(x, y, phase):
        u, v = x / w, y / h
        dx = 0
        dy = 0
        for cx, cy, rx, ry, mx, my, delay in controls:
            influence = weights(u, v, cx, cy, rx, ry) * math.sin(phase + delay)
            dx += w * mx * influence
            dy += h * my * influence
        return x - dx, y - dy

    poses = [frame(source, math.tau * n / 32, deform).convert("RGBA") for n in range(32)]
    poses[0].save(ROOT / f"{name}_idle.webp", save_all=True, append_images=poses[1:],
                  duration=duration // 32, loop=0, quality=89, method=4)


if __name__ == "__main__":
    for character, settings in CREW.items():
        export_crew(character, *settings)
