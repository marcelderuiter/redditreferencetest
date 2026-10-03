#!/usr/bin/env python3
"""Unattended look tuner: coordinate descent over the TUNE knobs.

Each evaluation renders the matched view with TUNE="key=value,..." (see
World.tune in godot/scripts/world.gd), predicts the graded image with the
same LUT fit tools/match.py makes, and scores it with compare.py. A step is
kept only when the predicted graded score rises and the spatial guardrails
hold (ssim and light_r from scripts/shot.py may not drop below the baseline
by more than a small margin), so the tuner cannot buy score by wrecking the
picture. Steps halve after a pass without gains.

It costs no model tokens: start it in the background and read the result.
  scripts/tune.py --minutes 110            # search, log captures/tune.jsonl
  scripts/tune.py --minutes 110 --bake --commit
      --bake    writes the best values into the tune("key", default) calls
      --commit  commits (and pushes) every pass that improved
  scripts/tune.py --only sun,ambient       # restrict the knobs
Best so far: captures/tune_best.json and captures/tune_best_sheet.png.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import shot  # noqa: E402
from shot import ROOT, OUT, compare, fit_lut  # noqa: E402

# key: (step, lo, hi, multiplicative). Defaults are read from the source.
KNOBS = {
    'exposure': (0.08, 0.6, 2.0, True),
    'ambient': (0.3, 0.0, 1.0, True),
    'sun': (0.15, 0.5, 6.0, True),
    'sun_spec': (0.3, 0.0, 1.5, True),
    'candle': (0.2, 0.3, 3.0, True),
    'fill': (0.4, 0.0, 1.5, True),
    'rim': (0.4, 0.0, 1.5, True),
    'pier': (0.25, 0.2, 3.0, True),
    'pier_rim': (0.3, 0.0, 2.0, True),
    'fog_hd': (0.4, 0.0, 0.5, True),
    'fog_height': (2.0, -20.0, 5.0, False),
    'bump': (0.3, 0.2, 3.0, True),
    'detail': (0.3, 0.2, 3.0, True),
}
SSIM_MARGIN = 0.003
LIGHT_MARGIN = 0.005
MIN_GAIN = 0.1
SOURCES = sorted((ROOT / 'godot' / 'scripts').glob('*.gd'))
CALL = r'tune\("{}", (-?[0-9.]+)\)'


def defaults():
    out = {}
    for src in SOURCES:
        text = src.read_text()
        for k in KNOBS:
            m = re.search(CALL.format(k), text)
            if m and k not in out:
                out[k] = float(m.group(1))
    return out


def bake(values):
    for src in SOURCES:
        text = src.read_text()
        new = text
        for k, v in values.items():
            new = re.sub(CALL.format(k), f'tune("{k}", {v:g})', new)
        if new != text:
            src.write_text(new)


def evaluate(values, ref, size, frames):
    os.environ['TUNE'] = ','.join(f'{k}={v:.4g}' for k, v in values.items())
    try:
        raw = compare.load(shot.render('tune_cur', frames, '', size), (ref.shape[1], ref.shape[0]))
    except SystemExit:
        return None
    grade = fit_lut.Grade(raw, ref)
    pred = fit_lut.apply_lut(fit_lut.bake(grade, 33), raw)
    m_raw, _, _ = compare.compare(raw, ref)
    m_pred, _, _ = compare.compare(pred, ref)
    res = {**shot.perceptual(pred, ref), 'raw': round(m_raw['score'], 2), 'graded': round(m_pred['score'], 2)}
    return res, pred


def git(*args):
    return subprocess.run(['git', '-C', str(ROOT), *args], capture_output=True, text=True)


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('--minutes', type=float, default=110)
    p.add_argument('--frames', default='16')
    p.add_argument('--only', default='', help='comma-separated knob subset')
    p.add_argument('--bake', action='store_true')
    p.add_argument('--commit', action='store_true')
    a = p.parse_args()
    OUT.mkdir(exist_ok=True)
    deadline = time.time() + a.minutes * 60
    ref = compare.load(ROOT / 'reference' / 'reference.png')
    size = f'{ref.shape[1]}x{ref.shape[0]}'
    keys = [k for k in (a.only.split(',') if a.only else KNOBS) if k in KNOBS]
    best = {k: v for k, v in defaults().items() if k in keys}
    steps = {k: KNOBS[k][0] for k in best}
    log = open(OUT / 'tune.jsonl', 'a')

    def record(values, res, pred, tag):
        log.write(json.dumps({'t': round(time.time()), 'tag': tag, **res, 'values': values}) + '\n')
        log.flush()
        if tag in ('base', 'keep'):
            (OUT / 'tune_best.json').write_text(json.dumps({**res, 'values': values}, indent=1))
            shot.side_by_side([np.clip(pred, 0, 1), ref], OUT / 'tune_best_sheet.png')

    out = evaluate(best, ref, size, a.frames)
    if out is None:
        sys.exit('baseline render failed')
    base, pred = out
    record(best, base, pred, 'base')
    print('base', json.dumps(base), flush=True)
    cur = base
    pass_no = 0
    while time.time() < deadline and any(steps[k] > KNOBS[k][0] / 8 for k in steps):
        pass_no += 1
        gained = False
        for k in best:
            if time.time() >= deadline:
                break
            step, lo, hi, mult = KNOBS[k]
            for sign in (1, -1):
                moved = False
                while time.time() < deadline:
                    v = best[k] * (1 + steps[k]) ** sign if mult else best[k] + sign * steps[k]
                    if mult and best[k] == 0:
                        v = steps[k] * 0.1 if sign > 0 else 0
                    v = round(min(hi, max(lo, v)), 4)
                    if v == best[k]:
                        break
                    trial = {**best, k: v}
                    out = evaluate(trial, ref, size, a.frames)
                    if out is None:
                        break
                    res, pred = out
                    ok = (res['graded'] > cur['graded'] + MIN_GAIN and res['ssim'] >= base['ssim'] - SSIM_MARGIN
                          and res['light_r'] >= base['light_r'] - LIGHT_MARGIN)
                    record(trial, res, pred, 'keep' if ok else 'drop')
                    print(f'{k}={v:g} graded {res["graded"]} ssim {res["ssim"]} light_r {res["light_r"]}',
                          'KEEP' if ok else '', flush=True)
                    if not ok:
                        break
                    best, cur, moved, gained = trial, res, True, True
                if moved:
                    break
        if not gained:
            steps = {k: s / 2 for k, s in steps.items()}
        elif a.bake:
            bake(best)
            if a.commit:
                git('add', 'godot/scripts')
                msg = (f'tune.py pass {pass_no}: predicted graded {cur["graded"]}\n\n'
                       f'{json.dumps(best)}\n\n'
                       'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n'
                       'Claude-Session: https://claude.ai/code/session_01VuAB1xdzQ8TpsS4xJz25aQ')
                git('commit', '-m', msg)
                br = git('rev-parse', '--abbrev-ref', 'HEAD').stdout.strip()
                for wait in (0, 2, 4, 8, 16):
                    time.sleep(wait)
                    if git('push', '-u', 'origin', br).returncode == 0:
                        break
    print('best', json.dumps({**cur, 'values': best}), flush=True)


if __name__ == '__main__':
    main()
