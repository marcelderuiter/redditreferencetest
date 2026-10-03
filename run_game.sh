#!/usr/bin/env bash
# Run the game, or prepare/check it.
#   ./run_game.sh               play (needs a display)
#   ./run_game.sh --build-only  import the project (builds Godot's class cache) and exit
#   ./run_game.sh --check       headless layout + reachability check (exit 1 on failure)
#   ./run_game.sh -- ARGS       pass user args to the game, e.g. -- --cam=0,44,110,16
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT_BIN:-godot}"
if [ ! -f godot/.godot/global_script_class_cache.cfg ] || [ "${1:-}" = "--build-only" ]; then
	"$GODOT" --headless --path godot --import >/dev/null 2>&1 || true
fi
case "${1:-}" in
	--build-only) exit 0 ;;
	--check)
		out="$("$GODOT" --headless --path godot -- --check 2>&1)" || status=$?
		echo "$out" | grep -vE "ObjectDB|cleanup|^\s*at:|^$" || true
		# A script that fails to compile prints no report: treat that as failure.
		echo "$out" | grep -q "reachability: every walkable cell is reachable" && [ "${status:-0}" = 0 ]
		;;
	--) shift; exec "$GODOT" --path godot -- "$@" ;;
	*) exec "$GODOT" --path godot ;;
esac
