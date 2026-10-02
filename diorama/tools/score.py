#!/usr/bin/env python3
"""Score a capture against reference/reference.png and write a comparison sheet.

Usage: diorama/tools/score.py CAPTURE.png [--sheet OUT.png]

Four terms, each 0..1, combined into a 0..100 score:
  layout   correlation of blurred luminance (where bright and dark masses sit)
  colour   mean OKLab distance of a coarse 16x12 colour grid
  tone     earth mover's distance between lightness histograms
  detail   ratio of fine-gradient energy (miniature crunchiness)
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT / 'reference' / 'reference.png'


def srgb_to_oklab(rgb):
    c = rgb / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                   [0.2119034982, 0.6806995451, 0.1073969566],
                   [0.0883024619, 0.2817188376, 0.6299787005]])
    lms = np.cbrt(lin @ m1.T)
    m2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                   [1.9779984951, -2.4285922050, 0.4505937099],
                   [0.0259040371, 0.7827717662, -0.8086757660]])
    return lms @ m2.T


def load(path, size):
    return np.asarray(Image.open(path).convert('RGB').resize(size, Image.LANCZOS)).astype(np.float64)


def grid(img, gw, gh):
    return np.asarray(Image.fromarray(img.astype(np.uint8)).resize((gw, gh), Image.BOX)).astype(np.float64)


def detail(img):
    g = np.asarray(Image.fromarray(img.astype(np.uint8)).convert('L')).astype(np.float64)
    blur = np.asarray(Image.fromarray(g.astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))).astype(np.float64)
    return np.abs(g - blur).mean()


def score(cap, ref):
    out = {}
    lc, lr = (srgb_to_oklab(grid(x, 48, 36))[..., 0] for x in (cap, ref))
    lc, lr = lc - lc.mean(), lr - lr.mean()
    out['layout'] = max(0.0, float((lc * lr).sum() / np.sqrt((lc ** 2).sum() * (lr ** 2).sum())))
    gc, gr = (srgb_to_oklab(grid(x, 16, 12)) for x in (cap, ref))
    out['colour'] = float(max(0.0, 1 - np.linalg.norm(gc - gr, axis=2).mean() / 0.15))
    hc, hr = (np.sort(srgb_to_oklab(grid(x, 270, 202))[..., 0].ravel()) for x in (cap, ref))
    out['tone'] = float(max(0.0, 1 - np.abs(hc - hr).mean() / 0.15))
    dc, dr = detail(cap), detail(ref)
    out['detail'] = float(min(dc, dr) / max(dc, dr))
    out['detail_ratio'] = dc / dr
    out['score'] = 100 * (0.35 * out['layout'] + 0.25 * out['colour'] + 0.25 * out['tone'] + 0.15 * out['detail'])
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument('capture')
    p.add_argument('--sheet')
    a = p.parse_args()
    ref_img = Image.open(REF).convert('RGB')
    size = ref_img.size
    ref = np.asarray(ref_img).astype(np.float64)
    cap = load(a.capture, size)
    s = score(cap, ref)
    print('score {score:.1f}  layout {layout:.3f}  colour {colour:.3f}  tone {tone:.3f}  '
          'detail {detail:.3f} (x{detail_ratio:.2f})'.format(**s))
    if a.sheet:
        sheet = Image.new('RGB', (size[0] * 2, size[1]))
        sheet.paste(Image.fromarray(cap.astype(np.uint8)), (0, 0))
        sheet.paste(ref_img, (size[0], 0))
        sheet.save(a.sheet)
    return 0


if __name__ == '__main__':
    sys.exit(main())
