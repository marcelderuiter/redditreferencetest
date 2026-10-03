#!/usr/bin/env python3
"""Blend a render over the reference (and an edge overlay) to check placement.

Usage: scripts/overlay.py RENDER OUT.png
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent


def main():
    render, out = sys.argv[1], sys.argv[2]
    ref = Image.open(ROOT / 'reference' / 'reference.png').convert('RGB')
    img = Image.open(render).convert('RGB').resize(ref.size, Image.LANCZOS)
    # Reference in grey, render edges in cyan on top.
    grey = np.asarray(ref.convert('L')).astype(np.float32) / 255.0
    lum = img.convert('L')
    edges = np.asarray(lum.filter(ImageFilter.FIND_EDGES)).astype(np.float32) / 255.0
    boosted = np.clip(np.asarray(lum).astype(np.float32) / 255.0 * 2.5, 0, 1)
    edges = np.clip(edges * 4.0, 0, 1)
    rgb = np.stack([grey * 0.8 + boosted * 0.0, grey * 0.8, grey * 0.8], -1)
    rgb[..., 0] = np.clip(rgb[..., 0] * (1 - edges), 0, 1)
    rgb[..., 1] = np.clip(rgb[..., 1] + edges * 0.9, 0, 1)
    rgb[..., 2] = np.clip(rgb[..., 2] + edges * 0.9, 0, 1)
    Image.fromarray((rgb * 255).astype(np.uint8)).save(out)


if __name__ == '__main__':
    main()
