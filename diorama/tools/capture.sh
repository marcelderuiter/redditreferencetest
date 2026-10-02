#!/bin/sh
# Usage: tools/capture.sh TAG [extra user args...]
# Renders the default view at the reference size and scores it.
set -eu
cd "$(dirname "$0")/.."
tag=$1; shift
mkdir -p captures
if [ -z "${DISPLAY:-}" ]; then
    pgrep -x Xvfb >/dev/null || (Xvfb :99 -screen 0 1920x1200x24 >/dev/null 2>&1 &)
    sleep 1
    export DISPLAY=:99
fi
${GODOT_BIN:-godot} --path . -- --capture="$PWD/captures/$tag.png" --frames=${FRAMES:-10} --size=1080x810 "$@" 2>&1 \
    | grep -E "SCRIPT ERROR|SHADER ERROR|Parse Error|instances|Vulkan|OpenGL" || true
python3 tools/score.py "captures/$tag.png" --sheet "captures/${tag}_sheet.png"
