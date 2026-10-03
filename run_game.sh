#!/usr/bin/env bash
# Play, check or capture the game. Usage:
#   ./run_game.sh                 play (needs a display)
#   ./run_game.sh --check         headless walk-grid reachability check
#   ./run_game.sh --capture=out.png [--lut=off] [--size=1080x810] [--cam=...]
#   ./run_game.sh --topdown=out.png
# Without a display, captures run under Xvfb automatically.
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT_BIN:-godot}"
if [[ ! -d godot/.godot ]]; then
  "$GODOT" --headless --path godot --import >/dev/null 2>&1 || true
fi
if [[ "${1:-}" == "--check" ]]; then
  exec "$GODOT" --headless --path godot -- --check
fi
if [[ -z "${DISPLAY:-}" ]] && command -v xvfb-run >/dev/null; then
  exec xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path godot -- "$@"
fi
exec "$GODOT" --path godot -- "$@"
