---
name: recreate-reference
description: Rebuild or re-match a Godot 4.7 scene so its default view matches reference/reference.png (this one or a completely new image). Use when asked to recreate, match, or improve the match to a reference image, or to score renders with tools/match.py.
---

# Recreate a reference image in Godot

The repo already contains a working generic pipeline. **Reuse it; never start
from an empty project.** Most of the cost of the first build was discovering
the pitfalls listed at the bottom. Read only the files you need.

## Rules that always hold
- `tools/match.py`, `tools/compare.py` and `tools/fit_lut.py` are read-only. Use them unmodified.
- Do not modify `reference/` (git-ignored). Generate all geometry and materials in code and shaders; do not download assets.
- Godot accepts `--capture --lut=off|auto --frames --size --seed --vignette --cam`, quits after capture and applies `godot/luts/00_reference_match.cube` with `--lut=auto`.
- Report both scores: `tools/match.py --tag NAME` gives raw and graded. Run it under `xvfb-run -a` when DISPLAY is unset.
- Commit and push after every kept change. A stop hook enforces this.

## Cost-saving order of work
1. **Tune numbers first, for free.** `scripts/tune.py --minutes 110 --bake --commit`, run in the background. It uses no tokens and costs about 40 s per render. It searches exposure, ambient, sun, sun_spec, candle, fill, rim, pier, pier_rim, fog, bump and detail. Read `captures/tune_best.json` and `tune_best_sheet.png` when it finishes. To add a knob, wrap a constant in `World.tune("key", default)` and add it to `KNOBS`.
2. **Iterate with one fast shot.** Use `scripts/shot.py NAME --before PREV`, which takes about 1 min. It writes `captures/NAME_vs.png` (before | after | reference) and prints ssim, light_r, dE and the predicted graded score. Show the `_vs.png` to the user.
3. **Run `tools/match.py` only for milestones.** It takes 3–4 min. Add each result to the README score table.
4. Do not use subagents for small fixes. When you need agents, use at most 5: composition/camera, lighting/atmosphere, materials/geometry, perception and a critic.
   - The perception agent names the single largest mismatch, using `_vs.png` plus the metrics.
   - One specialist fixes it, and the critic keeps or reverts it.
   - Restart agents every 3–4 iterations so their context stays small.
   - Stop when 2 iterations in a row bring no visible gain.

## New reference image: pipeline
1. **Study.** View the image once and write `docs/reference_study.md`: palette, light sources, camera, structure, props, and atmosphere. `scripts/gridsheet.py` and `scripts/regions.py` give gridded crops and region statistics.
2. **Camera.** Fit the view with `scripts/viewmath.py`, which mirrors `rig.gd`: yaw, pitch, dist, fov, keystone and frustum offset. Put the result into `Rig.DEFAULT_VIEW`. Check it with `scripts/overlay.py` (render over the reference).
3. **Plan as data.** Replace `godot/scripts/plan.gd` with rooms, links between named rooms, and props with features.
   - `layout.gd` resolves shared walls, the walk grid and BFS reachability.
   - Run `./run_game.sh --check`; it must print the reachability line. Check the plan with `--topdown`.
4. **Build.** Add new kit pieces to `build.gd` and `props.gd` only when the image needs them; reuse the existing ones otherwise. Give every item its own RNG stream (`kit.stream(key, build)`), so adding one item does not reshuffle the others.
5. **Light.** Put the colour in the lights, not in paint.
   - Keep ambient low and use one key light (the sun as a distant SpotLight), local warm lights, and a faint fill.
   - Use fog for depth.
   - Then run tune.py.
6. **Loop** as in "Cost-saving order of work" above.

## What the metric rewards (compare.py)
- It ignores composition and uses OKLab distributions only. The LUT that `fit_lut` builds cancels global brightness and colour cast: a gamma 1.2 error still scores 97.1 after grading. Therefore exposure, fog colour and grading mostly do **not** matter for the graded score.
- What the LUT cannot fix:
  - the **detail** term (high-frequency energy), which is hyper-sensitive: a 0.5 px blur of the reference itself drops it to 84.2;
  - local contrast;
  - band shares, i.e. how much area is dark, mid and light;
  - hue mixing.
- So match the **amount of fine texture** (bump, detail, edge chips, MSAA) and **how much of the frame is lit**.
- Ceiling: the reference graded against itself, through match.py's 0.25 vignette, scores **98.7**, so 99 is not reachable. Plan on 92–95.
- Spatial metrics in shot.py are the sanity check that you are not just buying score: ssim (structure), light_r (where light falls) and dE.

## Pitfalls already paid for
- **Setup.** Download Godot from `downloads.godotengine.org`, since github.com is blocked. Run `godot --headless --import` (`./run_game.sh --build-only`) before the first run, and after adding a `class_name`; otherwise headless runs hang.
- **Rendering.** Use Forward+ on lavapipe under Xvfb. MSAA is set to 2.
- **Sun and shadows.**
  - DirectionalLight3D shadow splits break with a frustum offset, so the sun is a distant SpotLight3D.
  - The positional shadow atlas must be 32-bit (`atlas_16_bits=false`); otherwise diagonal false shadow bands appear.
- **Bloom** lifts every black and distorts the LUT fit, so keep bloom at 0. Glow threshold is 1.2.
- **Tonemapping.** Use AgX. Saturated orange pools turn red under other tonemappers, so make candles amber, around 2200 K (1.25, 0.72, 0.25).
- **Deep shafts.** Sunlit bevels on deep piers draw chalk outlines. Use a shadow-only sheet below the floors and gate rims to the sun.
- **Fog** hides lit far structure. Far background detail needs separate backdrop fog or a separate light layer.
- **Hanging objects** must hang from something: chains to beams. Shared walls between touching rooms are one wall, and the other room's floor extends.
- **GDScript.**
  - `:=` with untyped dict or array values fails to parse, so type them explicitly.
  - You cannot index a StringName key with `[0]`.
  - SurfaceTool needs a consistent vertex format (call `set_uv` everywhere) and clockwise front faces.
  - Varyings can only be written in `vertex()`.
  - Godot 4.7 MultiMesh scales normals non-inversely; correct them in the shader.
- **Bevels.** Use true-size metric bevels through the shared `metric_bevel()` shader function. A per-material `CHAMFER` table sets them.

## Files
- `godot/scripts/`:
  - `main.gd`: args, capture, check, topdown;
  - `rig.gd`: camera;
  - `world.gd`: environment, lights, backdrop and `tune()`;
  - `kit.gd`: meshes, materials, lights and RNG streams;
  - `layout.gd` and `plan.gd`: the level as data;
  - `build.gd` and `props.gd`: geometry;
  - `grade.gd` with `shaders/post.gdshader`: vignette and LUT.
- `scripts/`: shot.py, tune.py, viewmath.py, overlay.py, gridsheet.py and regions.py.
- `README.md` holds the score table and the loop history. Append to them; do not rewrite them.
