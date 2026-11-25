"""Export the transparent moving star and console layer for the painted bridge."""
from pathlib import Path
import math
import random
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / "assets/kvesmos/scenes"
SIZE = (444, 250)
sky = Image.new("L", SIZE)
ImageDraw.Draw(sky).polygon([(158,24),(212,15),(286,20),(353,39),(344,54),
                              (310,62),(286,77),(257,104),(243,128),(126,128)], fill=255)
stars = random.Random(36)
points = [(stars.randrange(122,355), stars.randrange(16,130),
           stars.randrange(12,32), stars.random()) for _ in range(56)]


def scene(t):
    dots = Image.new("RGBA", SIZE)
    paint = ImageDraw.Draw(dots)
    for x, y, speed, phase in points:
        # Fade at either end of each track to keep the loop seamless.
        progress = (t + phase) % 1
        alpha = round(195 * math.sin(math.pi * progress)**2)
        paint.ellipse((x-speed*progress,y,x-speed*progress+1,y+1), fill=(186,231,255,alpha))
    frame = Image.new("RGBA", SIZE)
    frame.paste(dots, (0, 0), sky)
    glow = Image.new("RGBA", SIZE)
    lights = ImageDraw.Draw(glow)
    for i, (x,y) in enumerate([(39,123),(62,128),(383,126),(419,118)]):
        strength = (1+math.sin(math.tau*t + i)) / 2
        lights.ellipse((x-9,y-4,x+9,y+4), fill=(81,237,238,round(62*strength)))
    return Image.alpha_composite(frame,glow.filter(ImageFilter.GaussianBlur(3)))


if __name__ == "__main__":
    frames = [scene(i/36) for i in range(36)]
    frames[0].save(ROOT/"bridge_lights.webp", save_all=True, append_images=frames[1:],
                   duration=125, loop=0, lossless=True)
