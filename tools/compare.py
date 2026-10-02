#!/usr/bin/env python3
"""Score a render against the visual reference.

Colour metrics are composition-independent: they compare distributions in
OKLab (lightness histogram, chroma by lightness band, hue mix of saturated
pixels). Two structural metrics compare local contrast and fine detail
energy. Lower distances are closer; `score` folds them into one 0-100 number.

Usage: tools/compare.py RENDER [--reference reference/reference.png]
                        [--sheet out.png] [--json]
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
BANDS = [(0.0, 0.2), (0.2, 0.35), (0.35, 0.5), (0.5, 0.65), (0.65, 1.01)]
HUES = ['red', 'orange', 'yellow', 'green', 'cyan', 'blue', 'purple', 'magenta']


def load(path, size=None):
    if not Path(path).is_file():
        sys.exit(f'{path}: not found (the reference image is supplied locally, see reference/README.md)')
    image = Image.open(path).convert('RGB')
    if size and image.size != size:
        image = image.resize(size, Image.LANCZOS)
    return np.asarray(image).astype(np.float64) / 255.0


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
               [0.2119034982, 0.6806995451, 0.1073969566],
               [0.0883024619, 0.2817188376, 0.6299787005]])
M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
               [1.9779984951, -2.4285922050, 0.4505937099],
               [0.0259040371, 0.7827717662, -0.8086757660]])
M2_INV = np.linalg.inv(M2)
M1_INV = np.linalg.inv(M1)


def oklab(srgb):
    return np.cbrt(srgb_to_linear(srgb) @ M1.T) @ M2.T


def oklab_to_srgb(lab):
    lms = lab @ M2_INV.T
    return linear_to_srgb((lms ** 3) @ M1_INV.T)


def emd_1d(a, b, bins, lo, hi):
    ha, _ = np.histogram(a, bins=bins, range=(lo, hi))
    hb, _ = np.histogram(b, bins=bins, range=(lo, hi))
    ca = np.cumsum(ha / max(ha.sum(), 1))
    cb = np.cumsum(hb / max(hb.sum(), 1))
    return float(np.abs(ca - cb).sum() * (hi - lo) / bins)


def hue_mix(lab):
    a, b = lab[..., 1].ravel(), lab[..., 2].ravel()
    chroma = np.hypot(a, b)
    keep = chroma > 0.03
    if keep.sum() == 0:
        return np.zeros(len(HUES))
    hue = (np.degrees(np.arctan2(b[keep], a[keep])) + 360.0) % 360.0
    # OKLab hue anchors (deg): red 20, orange 55, yellow 95, green 145,
    # cyan 195, blue 255, purple 300, magenta 340.
    anchors = np.array([20, 55, 95, 145, 195, 255, 300, 340])
    d = np.abs(((hue[:, None] - anchors[None, :]) + 180) % 360 - 180)
    idx = d.argmin(axis=1)
    w = chroma[keep]
    mix = np.bincount(idx, weights=w, minlength=len(HUES))
    return mix / max(mix.sum(), 1e-9)


def local_contrast(L):
    # Std of lightness in 16x16 tiles, averaged: how punchy local lighting is.
    h, w = L.shape
    t = 16
    L = L[: h // t * t, : w // t * t].reshape(h // t, t, w // t, t)
    return float(L.std(axis=(1, 3)).mean())


def detail_energy(L):
    # Mean absolute Laplacian: amount of fine surface detail.
    lap = np.abs(4 * L[1:-1, 1:-1] - L[:-2, 1:-1] - L[2:, 1:-1] - L[1:-1, :-2] - L[1:-1, 2:])
    return float(lap.mean())


def stats(lab):
    L = lab[..., 0]
    a, b = lab[..., 1], lab[..., 2]
    out = {
        'L_mean': float(L.mean()),
        'L_std': float(L.std()),
        'L_p': [float(v) for v in np.percentile(L, [5, 25, 50, 75, 95, 99])],
        'bands': [],
        'hues': [float(v) for v in hue_mix(lab)],
        'local_contrast': local_contrast(L),
        'detail': detail_energy(L),
    }
    for lo, hi in BANDS:
        m = (L >= lo) & (L < hi)
        frac = float(m.mean())
        if m.sum() > 0:
            out['bands'].append([frac, float(a[m].mean()), float(b[m].mean()), float(np.hypot(a[m], b[m]).mean())])
        else:
            out['bands'].append([frac, 0.0, 0.0, 0.0])
    return out


def compare(render, reference):
    lr, lf = oklab(render), oklab(reference)
    sr, sf = stats(lr), stats(lf)
    m = {}
    m['L_emd'] = emd_1d(lr[..., 0], lf[..., 0], 100, 0.0, 1.0)
    m['a_emd'] = emd_1d(lr[..., 1], lf[..., 1], 100, -0.15, 0.15)
    m['b_emd'] = emd_1d(lr[..., 2], lf[..., 2], 100, -0.15, 0.15)
    # Tint error per lightness band, weighted by the reference band share.
    tint = 0.0
    for (fr, ar, br, cr), (ff, af, bf, cf) in zip(sr['bands'], sf['bands']):
        tint += ff * np.hypot(ar - af, br - bf)
    m['band_tint'] = float(tint)
    m['band_share'] = float(sum(abs(x[0] - y[0]) for x, y in zip(sr['bands'], sf['bands'])) * 0.5)
    m['hue_mix'] = float(np.abs(np.array(sr['hues']) - np.array(sf['hues'])).sum() * 0.5)
    m['contrast_ratio'] = sr['local_contrast'] / max(sf['local_contrast'], 1e-9)
    m['detail_ratio'] = sr['detail'] / max(sf['detail'], 1e-9)
    # Weighted score: 100 = identical distributions.
    penalty = (m['L_emd'] * 400 + (m['a_emd'] + m['b_emd']) * 600 + m['band_tint'] * 800
               + m['band_share'] * 60 + m['hue_mix'] * 40
               + abs(np.log(max(m['contrast_ratio'], 1e-6))) * 25
               + abs(np.log(max(m['detail_ratio'], 1e-6))) * 15)
    m['penalty'] = float(penalty)
    m['score'] = float(100.0 * np.exp(-penalty / 100.0))
    return m, sr, sf


def sheet(render, reference, path):
    h = 360
    def thumb(img):
        im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
        return im.resize((int(im.width * h / im.height), h), Image.LANCZOS)
    a, b = thumb(render), thumb(reference)
    out = Image.new('RGB', (a.width + b.width + 8, h), (255, 255, 255))
    out.paste(a, (0, 0))
    out.paste(b, (a.width + 8, 0))
    out.save(path)


def report(m, sr, sf):
    lines = [f"score {m['score']:.1f}/100 (penalty {m['penalty']:.1f})"]
    lines.append(f"  lightness EMD {m['L_emd']:.4f}   a EMD {m['a_emd']:.4f}   b EMD {m['b_emd']:.4f}")
    lines.append(f"  band tint {m['band_tint']:.4f}   band share {m['band_share']:.3f}   hue mix {m['hue_mix']:.3f}")
    lines.append(f"  local contrast x{m['contrast_ratio']:.2f}   detail x{m['detail_ratio']:.2f}")
    lines.append(f"  L mean {sr['L_mean']:.3f} (ref {sf['L_mean']:.3f})  std {sr['L_std']:.3f} (ref {sf['L_std']:.3f})")
    lines.append('  L pct 5/25/50/75/95/99  render ' + ' '.join(f'{v:.2f}' for v in sr['L_p']))
    lines.append('                          ref    ' + ' '.join(f'{v:.2f}' for v in sf['L_p']))
    lines.append('  band        share r/ref     a r/ref          b r/ref          chroma r/ref')
    for (lo, hi), x, y in zip(BANDS, sr['bands'], sf['bands']):
        lines.append(f'  L{lo:.2f}-{min(hi, 1):.2f}  {x[0]:.2f}/{y[0]:.2f}   {x[1]:+.3f}/{y[1]:+.3f}   {x[2]:+.3f}/{y[2]:+.3f}   {x[3]:.3f}/{y[3]:.3f}')
    lines.append('  hue mix     ' + ' '.join(f'{n[:3]} {x:.2f}/{y:.2f}' for n, x, y in zip(HUES, sr['hues'], sf['hues'])))
    return '\n'.join(lines)


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('render')
    p.add_argument('--reference', default=str(ROOT / 'reference' / 'reference.png'))
    p.add_argument('--sheet')
    p.add_argument('--json', action='store_true')
    args = p.parse_args()
    reference = load(args.reference)
    render = load(args.render, (reference.shape[1], reference.shape[0]))
    m, sr, sf = compare(render, reference)
    if args.sheet:
        sheet(render, reference, args.sheet)
    if args.json:
        json.dump({'metrics': m, 'render': sr, 'reference': sf}, sys.stdout, indent=1)
        print()
    else:
        print(report(m, sr, sf))


if __name__ == '__main__':
    main()
