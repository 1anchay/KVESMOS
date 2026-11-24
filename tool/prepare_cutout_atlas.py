"""Prepare eight generated animation layers for runtime joint animation."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import binary_propagation

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("source", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
source = Image.open(args.source).convert("RGBA")
target = Image.new("RGBA", (1024, 512))
for cell in range(8):
    left = round(source.width * (cell % 4) / 4)
    top = round(source.height * (cell // 4) / 2)
    right = round(source.width * (cell % 4 + 1) / 4)
    bottom = round(source.height * (cell // 4 + 1) / 2)
    layer = source.crop((left + 5, top + 5, right - 5, bottom - 5))
    rgb = np.asarray(layer.convert("RGB"))
    matte = np.median(np.concatenate(
        (rgb[:8, :8], rgb[:8, -8:]), axis=1), axis=(0, 1))
    background = np.max(np.abs(rgb.astype(float) - matte), axis=2) < 45
    edge = np.zeros(background.shape, dtype=bool)
    edge[[0, -1], :] = True
    edge[:, [0, -1]] = True
    outside = binary_propagation(edge & background, mask=background)
    layer = Image.fromarray(np.dstack((rgb, (~outside).astype("uint8") * 255)))
    bounds = layer.getbbox()
    if bounds is None:
        raise ValueError(f"Empty animation layer {cell}")
    layer = layer.crop(bounds)
    layer.thumbnail((240, 240), Image.Resampling.LANCZOS)
    x = (cell % 4) * 256 + (256 - layer.width) // 2
    y = (cell // 4) * 256 + (256 - layer.height) // 2
    target.paste(layer, (x, y))
args.output.parent.mkdir(parents=True, exist_ok=True)
target.save(args.output, lossless=True, method=6)
