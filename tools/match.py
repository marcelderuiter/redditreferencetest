#!/usr/bin/env python3
"""One-shot reference matching loop:
  1. capture the raw render (LUT off, no vignette) at the reference size,
  2. fit godot/luts/00_reference_match.cube to the reference,
  3. capture the graded render in-engine and score it,
  4. write a side-by-side sheet.

Usage: tools/match.py [--seed 7] [--strength 1.0] [--frames 45] [--no-fit]
                      [--cam yaw,pitch,dist,fov[,fx,fy,fz]] [--tag NAME]
Requires a display (Godot renders in a window); run ./run_game.sh --build-only first.
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import compare  # noqa: E402
import fit_lut  # noqa: E402

GODOT = os.environ.get('GODOT_BIN', 'godot')


def capture(path, lut, frames, seed, cam, vignette, size):
    args = [GODOT, '--path', str(ROOT / 'godot'), '--', f'--capture={path}', f'--lut={lut}',
            f'--frames={frames}', f'--size={size}', f'--seed={seed}', f'--vignette={vignette}']
    if cam:
        args.append(f'--cam={cam}')
    result = subprocess.run(args, capture_output=True, text=True, timeout=300)
    errors = [l for l in (result.stdout + result.stderr).splitlines() if 'ERROR' in l or 'SHADER ERROR' in l]
    if errors:
        print('\n'.join(errors[:10]))
    if not Path(path).exists():
        sys.exit(f'capture failed: {path}')


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('--seed', default='7')
    p.add_argument('--strength', type=float, default=1.0)
    p.add_argument('--frames', default='45')
    p.add_argument('--cam', default='')
    p.add_argument('--tag', default='match')
    p.add_argument('--no-fit', action='store_true')
    p.add_argument('--vignette', default='0.25')
    args = p.parse_args()
    out = ROOT / 'captures'
    out.mkdir(exist_ok=True)
    raw = out / f'{args.tag}_raw.png'
    graded = out / f'{args.tag}_graded.png'
    # Captures render at the reference's own size.
    ref = compare.load(ROOT / 'reference' / 'reference.png')
    size = f'{ref.shape[1]}x{ref.shape[0]}'
    capture(raw, 'off', args.frames, args.seed, args.cam, args.vignette, size)
    raw_img = compare.load(raw, (ref.shape[1], ref.shape[0]))
    if not args.no_fit:
        grade = fit_lut.Grade(raw_img, ref, args.strength)
        table = fit_lut.bake(grade, 33)
        fit_lut.write_cube(table, ROOT / 'godot' / 'luts' / '00_reference_match.cube', 'Reference Match')
    capture(graded, 'auto', args.frames, args.seed, args.cam, args.vignette, size)
    graded_img = compare.load(graded, (ref.shape[1], ref.shape[0]))
    m_raw, _, _ = compare.compare(raw_img, ref)
    m, sr, sf = compare.compare(graded_img, ref)
    print(f'raw score {m_raw["score"]:.1f}  graded score {m["score"]:.1f}')
    print(compare.report(m, sr, sf))
    compare.sheet(graded_img, ref, out / f'{args.tag}_sheet.png')
    print(f'sheet: {out / (args.tag + "_sheet.png")}')


if __name__ == '__main__':
    main()
