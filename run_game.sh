#!/usr/bin/env bash
# Run the game, or prepare/check it.
#   ./run_game.sh               play (needs a display)
#   ./run_game.sh --build-only  import the project (class cache) and exit
#   ./run_game.sh --check       headless layout + reachability check
#   ./run_game.sh -- ARGS       pass user args to the game (e.g. --cam=...)
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT_BIN:-godot}"
if [ ! -f godot/.godot/global_script_class_cache.cfg ] || [ "${1:-}" = "--build-only" ]; then
	"$GODOT" --headless --path godot --import >/dev/null 2>&1 || true
fi
case "${1:-}" in
	--build-only) exit 0 ;;
	--check) exec "$GODOT" --headless --path godot -- --check ;;
	--) shift; exec "$GODOT" --path godot -- "$@" ;;
	*) exec "$GODOT" --path godot ;;
esac
