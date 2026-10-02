#!/usr/bin/env python3
"""Fit a colour-grade LUT that moves a raw render's colour distribution onto
the reference image's, and bake it as a 3D .cube (display sRGB in and out).

Model, in OKLab:
  1. Lightness: smoothed, slope-limited histogram matching L -> f(L).
  2. Chroma: per lightness band, an affine transfer of (a, b) that matches the
     reference band's mean tint and spread (split toning learned from data).
  3. Out-of-gamut results are pulled toward grey at constant lightness.
The fitted mapping is blended with identity by --strength, baked on a grid,
then applied back to the raw render to report the predicted score.

Usage: tools/fit_lut.py RAW_RENDER [--reference reference/reference.png]
       [--out godot/luts/00_reference_match.cube] [--size 33] [--strength 1]
       [--preview captures/predicted.png]
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import compare  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
BINS = 14


def smooth(values, sigma):
    if sigma <= 0:
        return values
    radius = int(sigma * 3) + 1
    x = np.arange(-radius, radius + 1)
    k = np.exp(-x * x / (2 * sigma * sigma))
    k /= k.sum()
    padded = np.pad(values, radius, mode='edge')
    return np.convolve(padded, k, mode='valid')


def fit_lightness(src, ref, grid=256, min_slope=0.35, max_slope=3.0):
    q = np.linspace(0.0, 1.0, 1001)
    sq = np.quantile(src, q)
    rq = np.quantile(ref, q)
    # Anchor the ends so black stays black and the curve extends sensibly.
    sq = np.concatenate([[0.0], sq, [1.0]])
    rq = np.concatenate([[0.0], rq, [max(rq[-1], 1.0)]])
    sq, idx = np.unique(sq, return_index=True)
    rq = rq[idx]
    x = np.linspace(0.0, 1.0, grid)
    f = np.interp(x, sq, rq)
    f = smooth(f, 4.0)
    slope = np.clip(np.diff(f) / np.diff(x), min_slope, max_slope)
    f = np.concatenate([[f[0]], f[0] + np.cumsum(slope * np.diff(x))])
    return x, np.clip(f, 0.0, 1.2)


def band_stats(L, a, b, edges):
    out = np.full((len(edges) - 1, 4), np.nan)
    for i in range(len(edges) - 1):
        m = (L >= edges[i]) & (L < edges[i + 1])
        if m.sum() < 300:
            continue
        sa, sb = a[m], b[m]
        out[i] = [sa.mean(), sb.mean(), np.sqrt((sa.var() + sb.var()) * 0.5), m.mean()]
    # Fill empty bands from neighbours.
    for c in range(3):
        col = out[:, c]
        good = ~np.isnan(col)
        if good.sum() == 0:
            col[:] = 0.0 if c < 2 else 0.02
        else:
            col[~good] = np.interp(np.flatnonzero(~good), np.flatnonzero(good), col[good])
    return out


class Grade:
    def __init__(self, raw, ref, strength=1.0, chroma_limit=(0.5, 1.8)):
        ls, lr = compare.oklab(raw).reshape(-1, 3), compare.oklab(ref).reshape(-1, 3)
        self.lx, self.lf = fit_lightness(ls[:, 0], lr[:, 0])
        mapped = self.lightness(ls[:, 0])
        self.edges = np.linspace(0.0, 1.0, BINS + 1)
        self.centres = (self.edges[:-1] + self.edges[1:]) * 0.5
        s = band_stats(mapped, ls[:, 1], ls[:, 2], self.edges)
        r = band_stats(lr[:, 0], lr[:, 1], lr[:, 2], self.edges)
        self.src_mean = np.stack([smooth(s[:, 0], 1.0), smooth(s[:, 1], 1.0)], 1)
        self.ref_mean = np.stack([smooth(r[:, 0], 1.0), smooth(r[:, 1], 1.0)], 1)
        self.scale = smooth(np.clip(r[:, 2] / np.maximum(s[:, 2], 1e-4), *chroma_limit), 1.0)
        self.strength = strength

    def lightness(self, L):
        return np.interp(L, self.lx, self.lf)

    def __call__(self, lab):
        L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
        L2 = self.lightness(L)
        sa = np.interp(L2, self.centres, self.src_mean[:, 0])
        sb = np.interp(L2, self.centres, self.src_mean[:, 1])
        ra = np.interp(L2, self.centres, self.ref_mean[:, 0])
        rb = np.interp(L2, self.centres, self.ref_mean[:, 1])
        k = np.interp(L2, self.centres, self.scale)
        a2 = ra + (a - sa) * k
        b2 = rb + (b - sb) * k
        out = np.stack([L2, a2, b2], -1)
        return lab + (out - lab) * self.strength


def to_srgb_gamut(lab):
    """OKLab -> display sRGB, desaturating at constant L until in gamut."""
    lo = np.zeros(lab.shape[:-1])
    hi = np.ones(lab.shape[:-1])

    def linear(scale):
        x = lab.copy()
        x[..., 1:] *= scale[..., None]
        return (x @ compare.M2_INV.T) ** 3 @ compare.M1_INV.T

    lin = linear(hi)
    ok = np.all((lin >= -1e-4) & (lin <= 1.0 + 1e-4), -1)
    for _ in range(14):
        mid = (lo + hi) * 0.5
        inside = np.all((linear(mid) >= -1e-4) & (linear(mid) <= 1.0 + 1e-4), -1)
        lo = np.where(inside, mid, lo)
        hi = np.where(inside, hi, mid)
    scale = np.where(ok, 1.0, lo)
    return compare.linear_to_srgb(linear(scale))


def bake(grade, size):
    v = np.linspace(0.0, 1.0, size)
    # .cube order: red fastest, then green, then blue.
    b, g, r = np.meshgrid(v, v, v, indexing='ij')
    rgb = np.stack([r, g, b], -1).reshape(-1, 3)
    return np.clip(to_srgb_gamut(grade(compare.oklab(rgb))), 0.0, 1.0).reshape(size, size, size, 3)


def apply_lut(table, image):
    """Trilinear lookup; table indexed [b][g][r]."""
    n = table.shape[0]
    p = np.clip(image, 0.0, 1.0) * (n - 1)
    i0 = np.minimum(np.floor(p).astype(int), n - 2)
    t = p - i0
    r0, g0, b0 = i0[..., 0], i0[..., 1], i0[..., 2]
    tr, tg, tb = t[..., 0:1], t[..., 1:2], t[..., 2:3]
    out = 0.0
    for db in (0, 1):
        for dg in (0, 1):
            for dr in (0, 1):
                w = (tr if dr else 1 - tr) * (tg if dg else 1 - tg) * (tb if db else 1 - tb)
                out = out + w * table[b0 + db, g0 + dg, r0 + dr]
    return out


def write_cube(table, path, title):
    n = table.shape[0]
    lines = ['# Generated by tools/fit_lut.py; display sRGB in, display sRGB out.',
             f'TITLE "{title}"', f'LUT_3D_SIZE {n}', 'DOMAIN_MIN 0.0 0.0 0.0', 'DOMAIN_MAX 1.0 1.0 1.0']
    flat = table.reshape(-1, 3)
    lines += [f'{c[0]:.5f} {c[1]:.5f} {c[2]:.5f}' for c in flat]
    Path(path).write_text('\n'.join(lines) + '\n')


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('raw')
    p.add_argument('--reference', default=str(ROOT / 'reference' / 'reference.png'))
    p.add_argument('--out', default=str(ROOT / 'godot' / 'luts' / '00_reference_match.cube'))
    p.add_argument('--size', type=int, default=33)
    p.add_argument('--strength', type=float, default=1.0)
    p.add_argument('--title', default='Reference Match')
    p.add_argument('--preview')
    args = p.parse_args()
    ref = compare.load(args.reference)
    raw = compare.load(args.raw, (ref.shape[1], ref.shape[0]))
    grade = Grade(raw, ref, args.strength)
    table = bake(grade, args.size)
    write_cube(table, args.out, args.title)
    graded = apply_lut(table, raw)
    before, _, _ = compare.compare(raw, ref)
    after, sr, sf = compare.compare(graded, ref)
    print(f'wrote {args.out}')
    print(f'lightness curve (in -> out): ' + ' '.join(f'{x:.2f}->{grade.lightness(x):.2f}' for x in (0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8)))
    print('band tint (centre: a,b src -> ref, chroma scale):')
    for c, s, r, k in zip(grade.centres, grade.src_mean, grade.ref_mean, grade.scale):
        print(f'  L{c:.2f}: {s[0]:+.3f},{s[1]:+.3f} -> {r[0]:+.3f},{r[1]:+.3f}  x{k:.2f}')
    print(f'raw score {before["score"]:.1f} -> predicted graded score {after["score"]:.1f}')
    print(compare.report(after, sr, sf))
    if args.preview:
        Image.fromarray((np.clip(graded, 0, 1) * 255).astype(np.uint8)).save(args.preview)


if __name__ == '__main__':
    main()
