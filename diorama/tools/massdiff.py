#!/usr/bin/env python3
"""Side-by-side of blurred lightness (capture | reference | signed diff) to see layout errors."""
import sys
import numpy as np
from PIL import Image
from score import REF, grid, load, srgb_to_oklab
ref = np.asarray(Image.open(REF).convert('RGB')).astype(float)
cap = load(sys.argv[1], (ref.shape[1], ref.shape[0]))
lc, lr = (srgb_to_oklab(grid(x, 48, 36))[..., 0] for x in (cap, ref))
d = (lc - lr)
def im(a, lo, hi):
    a = np.clip((a - lo) / (hi - lo), 0, 1) * 255
    return Image.fromarray(a.astype(np.uint8)).resize((360, 270), Image.NEAREST)
out = Image.new('L', (1080, 270))
out.paste(im(lc, 0.1, 0.7), (0, 0)); out.paste(im(lr, 0.1, 0.7), (360, 0)); out.paste(im(d, -0.3, 0.3), (720, 0))
out.save(sys.argv[2])
