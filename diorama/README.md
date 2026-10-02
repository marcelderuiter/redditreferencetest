# Abyss Diorama (from-scratch build)

A small explorable game built from scratch to match `reference/reference.png`:
a candle-lit miniature dungeon of rooms on masonry piers above a blue-black
abyss, joined by timber and brass bridges. It shares no code or assets with the
rest of this repository. It is a self-contained Godot 4.7 project made of
GDScript and shaders only, with no models or textures; every stone, plank,
candle and figure is generated.

![Default view](docs/screenshot.png)

## Run

```sh
godot --path diorama                       # play
godot --path diorama -- --seed=3           # another seed (layout fixed, detail varies)
diorama/tools/capture.sh TAG [--cam=...]   # render 1080x810 and score vs the reference
```

`tools/capture.sh` starts Xvfb when there is no display. On a GPU-less Linux box
install `mesa-vulkan-drivers` so Godot runs Forward+ on lavapipe. Without it,
Godot falls back to the OpenGL Compatibility renderer, which has no SSAO and
caps lights per object.

| Control | Action |
| --- | --- |
| WASD / arrows | Walk the hero (camera-relative) over rooms, stairs, bridges and the lift |
| RMB drag / MMB drag / wheel | Orbit / pan / zoom |
| F | Follow the hero |
| Home / F12 / F1 / F11 | Reset camera / screenshot to `user://` / toggle help / fullscreen |

User args (after `--`): `--seed=N --cam=yaw,pitch,dist,fov,tx,ty,tz --size=WxH
--capture=PATH --frames=N --nohud`.

## Layout

- `layout.gd`: the authored plan, traced from the reference composition.
  It has ten rooms (gatehouse with dais and stairs, study, forge, long hall,
  ruined statue court, chapel, treasury, barracks with an east landing), the
  round brass mechanism platform, the hanging lift, six bridges, timber
  trestles in the gaps, and a gothic backdrop falling into the abyss.
- `kit.gd`: the building kit. It provides instance batching (one MultiMesh per
  mesh × material), irregular flagstones, ragged masonry walls with proud
  blocks, towers, piers, foundations, stairs, bridges, trestles, chains,
  furniture, candles (with lights), treasure and painted miniature figures.
- `walk.gd`: walkable surfaces (rects, ramps, bridge segments, circles). The
  hero picks the surface closest to its current height, and props block it.
- `shaders/kit.gdshader`: one procedural material for everything. It has
  modes for carved block (edge highlights from box-edge distance, a
  dry-brushed look), coursed masonry, wood grain, metal, carpet pattern and
  glow. `flame.gdshader` handles the flickering candle flames.

## Measuring

`tools/score.py` is a scorer written for this build. It combines layout
(correlation of blurred lightness), colour (OKLab error on a 16×12 grid), tone
(lightness-histogram distance) and detail (fine-gradient energy) into 0–100.
`tools/stats.py` prints lightness percentiles, and `tools/massdiff.py` shows
where the light and dark masses differ. `tools/camfit.py` fits the default
camera by coordinate descent on the score.

There is no LUT or post-grade: all scores are straight renders.

| Step | Score | Layout | Colour | Tone | Detail |
| --- | --- | --- | --- | --- | --- |
| First render (OpenGL fallback, top-down) | 50.6 | 0.35 | 0.36 | 0.66 | 0.87 |
| Forward+ on lavapipe, exposure and camera pitch fixed | 57.0 | 0.47 | 0.47 | 0.72 | 0.73 |
| Darker greyer stone, edge highlights, abyss lifted | 63.9 | 0.44 | 0.58 | 0.79 | 0.95 |
| Foundations, trestles, less orange light, fitted camera | 66.6 | 0.46 | 0.55 | 0.89 | 0.97 |
| Rooms re-placed to the reference footprint, refitted camera | 66.2 | 0.45 | 0.56 | 0.88 | 0.97 |
| Bigger candles/figures, darker substructure, blue abyss light | 64.8 | 0.45 | 0.55 | 0.89 | 0.89 |

The last row trades a little score for a closer look by eye (the brighter, more
uniform version scored higher). The remaining gap is mostly structural. The
reference's rooms are built of chunkier, more irregular masonry, and its
miniatures and props are far more detailed than these primitive-built stand-ins.

![Hero close-up](docs/closeup.png)

## Checks

```sh
godot --headless --path diorama --script res://tools/check.gd   # every area reachable from the spawn
```
