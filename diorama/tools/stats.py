#!/usr/bin/env python3
"""Print luminance percentiles and mean colour of a capture next to the reference."""
import sys
import numpy as np
from PIL import Image
from score import REF
for name, path in (('cap', sys.argv[1]), ('ref', REF)):
    a = np.asarray(Image.open(path).convert('RGB').resize((1080, 810))).astype(float)
    L = a.mean(2)
    print(name, 'pct5..99', np.percentile(L, [5, 25, 50, 75, 95, 99]).round(0), 'mean rgb', a.mean((0, 1)).round(1))
