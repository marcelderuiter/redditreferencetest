#!/usr/bin/env bash
# Play, check or capture the game. Usage:
#   ./run_game.sh                 play (needs a display)
#   ./run_game.sh --check         headless walk-grid reachability check
#   ./run_game.sh --capture=out.png [--lut=off] [--size=1080x810] [--cam=...]
#   ./run_game.sh --topdown=out.png
#   ./run_game.sh --walktest      headless: walk the player to every room
#   ./run_game.sh --inputtest     feed key events, check walking and camera reset
#   ./run_game.sh --build-only    import the project (nothing to compile)
# Without a display, captures run under Xvfb automatically.
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT_BIN:-godot}"
if [[ ! -d godot/.godot || "${1:-}" == "--build-only" ]]; then
  "$GODOT" --headless --path godot --import >/dev/null 2>&1 || true
fi
case "${1:-}" in
  --build-only) exit 0 ;;
  --check|--walktest) exec "$GODOT" --headless --path godot -- "$1" ;;
esac
if [[ -z "${DISPLAY:-}" ]] && command -v xvfb-run >/dev/null; then
  exec xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path godot -- "$@"
fi
exec "$GODOT" --path godot -- "$@"
