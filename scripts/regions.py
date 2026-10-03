#!/usr/bin/env python3
"""Compare mean OKLab of matching regions in a render and the reference.
Usage: scripts/regions.py RENDER"""
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import compare  # noqa: E402

REGIONS = {
    'abyss top-right': (990, 0, 1080, 60), 'abyss centre gap': (480, 380, 560, 450),
    'abyss bottom': (500, 620, 580, 800), 'pillar bottom-left': (30, 650, 100, 800),
    'pillar bottom-right': (900, 700, 1000, 800), 'hall floor': (380, 380, 430, 440),
    'cellar floor': (760, 600, 860, 660), 'throne front wall': (30, 520, 200, 560),
    'orrery disc': (700, 330, 860, 420), 'treasury': (900, 190, 1040, 290),
    'chapel': (740, 120, 870, 250), 'forge': (60, 180, 210, 300),
}


def main():
    ref = compare.load(ROOT / 'reference' / 'reference.png')
    img = compare.load(sys.argv[1], (ref.shape[1], ref.shape[0]))
    print(f'{"region":22s} {"render L a b":>22s}   {"reference L a b":>22s}')
    for name, (x0, y0, x1, y1) in REGIONS.items():
        r = compare.oklab(img[y0:y1, x0:x1]).reshape(-1, 3).mean(0)
        f = compare.oklab(ref[y0:y1, x0:x1]).reshape(-1, 3).mean(0)
        print(f'{name:22s} {r[0]:.3f} {r[1]:+.3f} {r[2]:+.3f}     {f[0]:.3f} {f[1]:+.3f} {f[2]:+.3f}')


if __name__ == '__main__':
    main()
