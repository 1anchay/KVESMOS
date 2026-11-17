"""Export selected approved drawing regions as transparent Flutter sprites.
Coordinates are expressed in the 768 px wide proof sheets.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import label

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/design-handoff/01_approved/characters"
OUT = ROOT / "assets/kvesmos/crew_motion"
# Per-character cells: thought, support, surprise, smile, speaking, signature gesture.
# The composition of each cell is preserved. The neutral portraits ship separately.
CELLS = {
    "aster": [(665,211,760,310),(498,213,576,306),(410,212,494,308),(583,213,655,307),(330,211,411,307),(332,323,487,507)],
    "fox_scholar": [(604,220,675,321),(326,220,410,320),(246,221,326,320),(680,219,757,321),(411,220,500,320),(392,328,483,502)],
    "miko": [(444,214,522,316),(607,212,680,316),(366,212,443,315),(524,213,605,316),(200,218,277,315),(148,340,281,507)],
    "nox": [(423,237,499,341),(506,237,583,341),(252,234,331,341),(588,237,668,341),(337,237,417,341),(413,353,579,573)],
    "reyvo": [(478,212,538,309),(703,213,758,307),(546,213,614,310),(622,211,690,307),(414,212,474,308),(350,315,474,488)],
    "vespa": [(420,221,483,309),(699,221,762,308),(491,219,549,307),(557,220,619,308),(216,223,275,307),(320,329,482,500)],
    "zig_quartz": [(551,233,649,327),(665,233,761,329),(446,234,544,328),(360,233,441,326),(255,232,348,326),(4,377,225,505)],
}
STATES = ("think", "support", "surprise", "happy", "talk", "gesture")


def cutout(cell, background, keep_props):
    rgb = np.asarray(cell.convert("RGB"), dtype=np.float32)
    bg = np.array(background)
    distance = np.max(np.abs(rgb - bg), axis=2)
    alpha = np.clip((distance - 11) / 35, 0, 1)
    regions, _ = label(alpha > .08)
    areas = np.bincount(regions.ravel())
    areas[0] = 0
    largest = areas.argmax()
    if keep_props:
        border = np.unique(np.concatenate((regions[0], regions[-1], regions[:, 0], regions[:, -1])))
        areas[border[border != largest]] = 0
        keep = areas >= (areas[largest] * .006)
    else:
        keep = np.arange(len(areas)) == largest
    alpha *= keep[regions]
    # Undo the white/beige matte on translucent outer pixels.
    straight = np.clip(bg + (rgb - bg) / np.maximum(alpha[..., None], .03), 0, 255)
    return Image.fromarray(np.dstack((straight, alpha * 255)).astype("uint8"))


def save(cell, name, state):
    cell = cell.crop(cell.getbbox())
    cell.thumbnail((288, 288), Image.Resampling.LANCZOS)
    # Keep a predictable optical centre and padding across portraits and props.
    target = Image.new("RGBA", (300, 300))
    target.paste(cell, ((300 - cell.width) // 2, (300 - cell.height) // 2))
    target.save(OUT / f"{name}_{state}.webp", lossless=True, method=6)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pixie-strip", type=Path, required=True)
    args = parser.parse_args()
    OUT.mkdir(exist_ok=True)
    for name, cells in CELLS.items():
        sheet = Image.open(SOURCE / f"{name}_sheet.png").convert("RGB")
        ratio = sheet.width / 768
        background = np.median(np.asarray(sheet)[:25, -25:, :], axis=(0, 1))
        for state, box in zip(STATES, cells):
            save(cutout(sheet.crop(tuple(round(v * ratio) for v in box)), background, state == "gesture"), name, state)
    pixie = Image.open(args.pixie_strip).convert("RGBA")
    for index, state in enumerate(("think", "surprise", "happy")):
        save(pixie.crop((pixie.width * index // 3, 0, pixie.width * (index + 1) // 3, pixie.height)), "pixie", state)


if __name__ == "__main__":
    main()
