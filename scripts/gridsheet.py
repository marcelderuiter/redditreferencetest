#!/usr/bin/env python3
"""Side-by-side render | reference with the same 100 px grid on both, for
judging placement by eye. Usage: scripts/gridsheet.py RENDER OUT.png [scale]"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent


def grid(im):
    d = ImageDraw.Draw(im)
    for x in range(0, im.width, 100):
        d.line([(x, 0), (x, im.height)], fill=(0, 200, 255), width=1)
    for y in range(0, im.height, 100):
        d.line([(0, y), (im.width, y)], fill=(0, 200, 255), width=1)
    return im


def main():
    ref = Image.open(ROOT / 'reference' / 'reference.png').convert('RGB')
    img = Image.open(sys.argv[1]).convert('RGB').resize(ref.size, Image.LANCZOS)
    scale = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
    a, b = grid(img), grid(ref.copy())
    out = Image.new('RGB', (ref.width * 2 + 6, ref.height), (255, 255, 255))
    out.paste(a, (0, 0))
    out.paste(b, (ref.width + 6, 0))
    out = out.resize((int(out.width * scale), int(out.height * scale)), Image.LANCZOS)
    out.save(sys.argv[2])


if __name__ == '__main__':
    main()
