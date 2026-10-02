#!/usr/bin/env python3
"""Coordinate-descent fit of the default camera against the reference score.
Usage: tools/camfit.py yaw,pitch,dist,fov,tx,ty,tz [rounds]"""
import subprocess
import sys
from pathlib import Path

D = Path(__file__).resolve().parents[1]
cam = [float(v) for v in sys.argv[1].split(',')]
rounds = int(sys.argv[2]) if len(sys.argv) > 2 else 2
steps = {1: 3.0, 2: 5.0, 4: 1.5, 6: 1.5, 0: 2.0}
cache = {}


def score(c):
    key = ','.join(f'{v:g}' for v in c)
    if key not in cache:
        out = subprocess.run([str(D / 'tools/capture.sh'), 'camfit', f'--cam={key}'], capture_output=True, text=True).stdout
        line = [l for l in out.splitlines() if l.startswith('score')][-1]
        cache[key] = float(line.split()[1])
        print(key, line, flush=True)
    return cache[key]


best = score(cam)
for r in range(rounds):
    for i, st in steps.items():
        for sign in (1, -1):
            while True:
                c = list(cam)
                c[i] += sign * st
                s = score(c)
                if s > best:
                    best, cam = s, c
                else:
                    break
    steps = {k: v * 0.5 for k, v in steps.items()}
print('BEST', ','.join(f'{v:g}' for v in cam), best)
