#!/usr/bin/env python3
"""Camera maths shared with godot/scripts/rig.gd, for planning layouts from the
reference image: project world points to pixels and unproject pixels onto a
horizontal plane. The matched view is an orbit camera whose image plane can be
kept partly vertical ("keystone"), like a shift lens, so tall pillars stay
upright while floors are still seen from above.

Usage: scripts/viewmath.py unproject X Y H   (pixel -> world X,Z on plane y=H)
       scripts/viewmath.py project X Y Z
"""
import math
import sys

import numpy as np

# Keep in sync with godot/scripts/rig.gd DEFAULT_VIEW.
VIEW = dict(yaw=0.0, pitch=44.0, dist=110.0, fov=16.0, focus=(0.0, 0.0, 0.0), keystone=0.45)
W, H = 1080, 810


def basis(v):
    yaw, pitch = math.radians(v['yaw']), math.radians(v['pitch'])
    f = np.array(v['focus'], float)
    c = f + v['dist'] * np.array([math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)])
    tilt = pitch * (1.0 - v['keystone'])  # how far the camera body itself pitches down
    fwd = np.array([-math.sin(yaw) * math.cos(tilt), -math.sin(tilt), -math.cos(yaw) * math.cos(tilt)])
    right = np.array([math.cos(yaw), 0.0, -math.sin(yaw)])
    up = np.cross(right, fwd)
    shift = -math.tan(pitch - tilt)  # frustum offset at unit distance (negative = look down)
    return c, right, up, fwd, shift


def project(p, v=VIEW, w=W, h=H):
    c, right, up, fwd, shift = basis(v)
    d = np.asarray(p, float) - c
    z = d @ fwd
    x, y = d @ right / z, d @ up / z - shift
    half = math.tan(math.radians(v['fov']) * 0.5)
    return (x / (half * w / h) + 1) * 0.5 * w, (1 - y / half) * 0.5 * h


def unproject(px, py, plane_y, v=VIEW, w=W, h=H):
    c, right, up, fwd, shift = basis(v)
    half = math.tan(math.radians(v['fov']) * 0.5)
    x = (px / w * 2 - 1) * half * w / h
    y = (1 - py / h * 2) * half + shift
    ray = fwd + right * x + up * y
    t = (plane_y - c[1]) / ray[1]
    return c + ray * t


if __name__ == '__main__':
    cmd, *a = sys.argv[1:]
    a = [float(s) for s in a]
    if cmd == 'unproject':
        p = unproject(a[0], a[1], a[2])
        print(f'{p[0]:.2f} {p[2]:.2f}')
    else:
        print('%.1f %.1f' % project(a))
