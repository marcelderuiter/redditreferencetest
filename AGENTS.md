# Reference Test

Read README.md. The goal is visual closeness to `reference/reference.png`;
measure it, don't eyeball it alone.

- Rust core (`src/`) owns generation, the walk grid and movement, and must
  build and run headlessly with no dependencies. Godot only presents output.
- After changing layout geometry, run `cargo run --release` (it must report
  every room reachable) and `cargo test --release` (mesh winding check).
- After visual changes, run `tools/match.py --tag NAME`. It needs a display
  and refits `godot/luts/00_reference_match.cube`. Report raw and graded
  scores, and keep the README progress table current.
- The LUT is the final grade, not a fix for wrong lighting. Prefer scene
  changes when the fitted curve is extreme (see the `fit_lut.py` printout).
- Core meshes are counter-clockwise; the adapter flips to Godot's clockwise.
  Varyings are written only via the `COMMON_VERTEX` macro (Godot forbids
  writing varyings in helper functions).
