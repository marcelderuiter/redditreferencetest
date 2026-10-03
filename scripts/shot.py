#!/usr/bin/env python3
"""Fast iteration render: capture the matched view (LUT off), predict the
graded image with the same LUT fit tools/match.py would make, and write
side-by-sides plus perceptual metrics against the reference.

Unlike tools/compare.py (colour distributions only), the perceptual metrics
here reward spatial agreement with the reference, which shares our framing:
  ssim        structural similarity of OKLab L at half resolution (1 = same)
  light_r     correlation of heavily blurred lightness (where light falls)
  dE          mean OKLab colour distance x100 at 1/8 resolution (lower = closer)
compare.py scores are printed as supporting evidence only.

Usage: scripts/shot.py NAME [--before NAME] [--frames 16] [--cam ...]
Writes captures/NAME_raw.png, NAME_pred.png, NAME_sheet.png (pred | ref),
NAME_grid.png (same with a 100 px grid) and, with --before, NAME_vs.png
(before | after | reference).
Needs a display; runs Godot under xvfb-run when DISPLAY is unset.
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter
from skimage.metrics import structural_similarity

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import compare  # noqa: E402
import fit_lut  # noqa: E402

OUT = ROOT / 'captures'
GODOT = os.environ.get('GODOT_BIN', 'godot')


def render(name, frames, cam, size):
    path = OUT / f'{name}_raw.png'
    args = [GODOT, '--path', str(ROOT / 'godot'), '--', f'--capture={path}', '--lut=off',
            f'--frames={frames}', f'--size={size}', '--seed=7', '--vignette=0.25']
    if cam:
        args.append(f'--cam={cam}')
    if not os.environ.get('DISPLAY'):
        args = ['xvfb-run', '-a', '-s', '-screen 0 1920x1080x24'] + args
    r = subprocess.run(args, capture_output=True, text=True, timeout=600)
    errs = [l for l in (r.stdout + r.stderr).splitlines() if 'SCRIPT ERROR' in l or 'SHADER ERROR' in l or 'Parse Error' in l]
    if errs:
        print('\n'.join(errs[:10]))
    if not path.exists():
        sys.exit(f'capture failed: {path}')
    return path


def perceptual(img, ref):
    li = compare.oklab(img)
    lr = compare.oklab(ref)
    half = lambda a: np.asarray(Image.fromarray(a.astype(np.float32)).resize((a.shape[1] // 2, a.shape[0] // 2), Image.BILINEAR))
    ssim = structural_similarity(half(li[..., 0]), half(lr[..., 0]), data_range=1.0, gaussian_weights=True, sigma=1.5)
    bi = gaussian_filter(li[..., 0], 20)
    br = gaussian_filter(lr[..., 0], 20)
    light_r = float(np.corrcoef(bi.ravel(), br.ravel())[0, 1])
    small = lambda a: np.stack([gaussian_filter(a[..., c], 4)[::8, ::8] for c in range(3)], -1)
    de = float(np.linalg.norm(small(li) - small(lr), axis=-1).mean() * 100)
    return {'ssim': round(float(ssim), 4), 'light_r': round(light_r, 4), 'dE': round(de, 3)}


def grid(im):
    d = ImageDraw.Draw(im)
    for x in range(0, im.width, 100):
        d.line([(x, 0), (x, im.height)], fill=(0, 200, 255), width=1)
    for y in range(0, im.height, 100):
        d.line([(0, y), (im.width, y)], fill=(0, 200, 255), width=1)
    return im


def side_by_side(images, path, scale=0.75, with_grid=False):
    ims = [Image.fromarray((np.clip(i, 0, 1) * 255).astype(np.uint8)) for i in images]
    if with_grid:
        ims = [grid(i) for i in ims]
    w, h = ims[0].size
    out = Image.new('RGB', (w * len(ims) + 8 * (len(ims) - 1), h), (255, 255, 255))
    for k, im in enumerate(ims):
        out.paste(im, (k * (w + 8), 0))
    out = out.resize((int(out.width * scale), int(out.height * scale)), Image.LANCZOS)
    out.save(path)


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('name')
    p.add_argument('--before')
    p.add_argument('--frames', default='16')
    p.add_argument('--cam', default='')
    a = p.parse_args()
    OUT.mkdir(exist_ok=True)
    ref = compare.load(ROOT / 'reference' / 'reference.png')
    size = f'{ref.shape[1]}x{ref.shape[0]}'
    raw = compare.load(render(a.name, a.frames, a.cam, size), (ref.shape[1], ref.shape[0]))
    grade = fit_lut.Grade(raw, ref)
    pred = fit_lut.apply_lut(fit_lut.bake(grade, 33), raw)
    Image.fromarray((np.clip(pred, 0, 1) * 255).astype(np.uint8)).save(OUT / f'{a.name}_pred.png')
    side_by_side([pred, ref], OUT / f'{a.name}_sheet.png')
    side_by_side([pred, ref], OUT / f'{a.name}_grid.png', 0.6, True)
    if a.before and (OUT / f'{a.before}_pred.png').exists():
        before = compare.load(OUT / f'{a.before}_pred.png')
        side_by_side([before, pred, ref], OUT / f'{a.name}_vs.png', 0.6)
    m_raw, _, _ = compare.compare(raw, ref)
    m_pred, _, _ = compare.compare(pred, ref)
    res = {'name': a.name, **perceptual(pred, ref), 'raw_score': round(m_raw['score'], 1), 'graded_score_pred': round(m_pred['score'], 1),
           'curve': ' '.join(f'{x:.1f}->{grade.lightness(x):.2f}' for x in (0.1, 0.3, 0.5, 0.7))}
    print(json.dumps(res))
    with open(OUT / 'shots.jsonl', 'a') as f:
        f.write(json.dumps(res) + '\n')


if __name__ == '__main__':
    main()
