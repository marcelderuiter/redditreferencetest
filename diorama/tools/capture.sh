#!/bin/sh
# Usage: tools/capture.sh TAG [extra game args, e.g. --cam=... --seed=N]
#
# The match loop of the repository's tools/match.py, pointed at this project:
#   1. capture the raw render (LUT off) at the reference size,
#   2. refit luts/00_reference_match.cube with ../tools/fit_lut.py,
#   3. capture the graded render in-engine and score both with ../tools/compare.py.
# RAW_ONLY=1 stops after scoring the raw render (no refit).
set -eu
cd "$(dirname "$0")/.."
repo_tools=../tools
tag=$1; shift
mkdir -p captures
if [ -z "${DISPLAY:-}" ]; then
    pgrep -x Xvfb >/dev/null || (Xvfb :99 -screen 0 1920x1200x24 >/dev/null 2>&1 &)
    sleep 1
    export DISPLAY=:99
fi
size=$(python3 -c "from PIL import Image; print('%dx%d' % Image.open('../reference/reference.png').size)")

capture() {  # capture OUT LUT [args]
    out=$1; lut=$2; shift 2
    timeout ${CAPTURE_TIMEOUT:-300} ${GODOT_BIN:-godot} --path . -- --capture="$PWD/$out" --frames=${FRAMES:-10} --size="$size" --lut="$lut" "$@" 2>&1 \
        | grep -E "SCRIPT ERROR|SHADER ERROR|Parse Error|OpenGL" || true
    [ -f "$out" ] || { echo "capture failed: $out" >&2; exit 1; }
}

rm -f "captures/${tag}_raw.png" "captures/${tag}_graded.png"
capture "captures/${tag}_raw.png" off "$@"
printf 'raw    '; python3 $repo_tools/compare.py "captures/${tag}_raw.png" | head -1
[ "${RAW_ONLY:-0}" = 1 ] && exit 0
python3 $repo_tools/fit_lut.py "captures/${tag}_raw.png" --out luts/00_reference_match.cube \
    --preview "captures/${tag}_predicted.png" > "captures/${tag}_fit.txt"
grep -E "lightness curve|predicted" "captures/${tag}_fit.txt"
capture "captures/${tag}_graded.png" auto "$@"
printf 'graded '; python3 $repo_tools/compare.py "captures/${tag}_graded.png" --sheet "captures/${tag}_sheet.png"
