"""Export intact illustrations from the approved KVESMOS character sheets.

The polygons follow the gutters between drawings. Remove only the background
connected to the sheet margins, preserving white eyes, gloves and faces.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_propagation, label

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "docs/design-handoff/01_approved/characters"
OUT = ROOT / "assets/kvesmos/crew_motion"
# Coordinates in a 390px-high reference (600px for Miko).
CUTS = {
    "miko": (600, [(0,0),(318,0),(318,146),(298,159),(292,224),(232,252),(223,281),(226,332),(249,370),(251,410),(0,410)]),
    "zig_quartz": (390, [(0,0),(206,0),(206,137),(194,156),(185,268),(174,276),(0,277)]),
    "aster": (390, [(0,0),(201,0),(200,157),(186,184),(183,245),(154,247),(157,273),(0,273)]),
    "reyvo": (390, [(0,0),(164,0),(165,152),(153,170),(150,213),(166,236),(166,262),(105,262),(94,251),(68,274),(0,274)]),
    "vespa": (390, [(0,0),(142,0),(146,62),(155,122),(158,163),(150,207),(136,288),(135,341),(148,356),(148,382),(0,382)]),
    "nox": (390, [(151,0),(226,0),(228,62),(231,102),(227,119),(237,150),(235,160),(180,160),(161,158),(153,152),(153,119),(161,99),(164,74),(163,56),(166,12)]),
    "fox_scholar": (390, [(202,6),(246,6),(250,45),(250,94),(246,112),(246,145),(252,161),(252,166),(184,166),(180,147),(180,122),(189,101),(196,64),(196,35)]),
}

# Sample the paper in enclosed gaps such as the space between a pair of boots.
PAPER_SAMPLES = {
    "miko": [(136,355)],
    "aster": [(80,249)],
    "zig_quartz": [(98,253)],
    "reyvo": [(90,226)],
    "vespa": [(73,296)],
    "fox_scholar": [(222,149)],
    "nox": [(181, 94)],
}

def export(name, height, outline):
    image = Image.open(ART / f"{name}_sheet.png").convert("RGB")
    scale = image.height / height
    matte = np.median(np.asarray(image)[:6, :6], axis=(0, 1)).astype(int)
    mask = Image.new("L", image.size)
    polygon = [(round(x * scale), round(y * scale)) for x, y in outline]
    ImageDraw.Draw(mask).polygon(polygon, fill=255)
    bounds = mask.getbbox()
    cell = Image.composite(image, Image.new("RGB", image.size, tuple(matte)), mask).crop(bounds)
    rgb = np.asarray(cell)
    paper = np.abs(rgb.astype(int) - matte).max(axis=2) < 34
    seeds = np.zeros_like(paper)
    seeds[[0, -1], :] = True
    seeds[:, [0, -1]] = True
    for x, y in PAPER_SAMPLES.get(name, []):
        seeds[round(y * scale) - bounds[1], round(x * scale) - bounds[0]] = True
    opaque = ~binary_propagation(seeds & paper, mask=paper)
    if name in {"nox", "fox_scholar"}:
        # Turnaround sheets place adjacent views close together.
        regions, _ = label(opaque)
        largest = np.bincount(regions[opaque]).argmax()
        opaque = regions == largest
    # The source sheets use a pale cast shadow. Trace up from the paper to the
    # outline of each sole, leaving opaque highlights inside the shoe intact.
    if name != "nox":
        floor = round(opaque.shape[0] * .85)
        bottom = rgb[floor:].astype(int)
        shadow = (bottom.min(axis=2) > 144) & (bottom.max(axis=2) - bottom.min(axis=2) < 72)
        clear = np.logical_and.accumulate((~opaque[floor:] | shadow)[::-1], axis=0)[::-1]
        opaque[floor:] &= ~clear
        regions, _ = label(opaque)
        counts = np.bincount(regions.ravel())
        floor_fragments = np.unique(regions[floor:])
        for region in floor_fragments:
            if region and counts[region] < 75 * scale ** 2:
                opaque[regions == region] = False
    art = Image.fromarray(np.dstack((rgb, 255 * opaque.astype("uint8"))))
    art = art.crop(art.getbbox())
    art.thumbnail((400, 448), Image.Resampling.LANCZOS)
    art.save(OUT / f"{name}_bridge.webp", lossless=True)


if __name__ == "__main__":
    for name, (height, outline) in CUTS.items():
        export(name, height, outline)
