#!/bin/sh
set -eu

script=$(readlink -f -- "$0")
cd -- "$(dirname -- "$script")"
project_root=$PWD
build_only=false
editor=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        --build-only) build_only=true; shift ;;
        --editor) editor=true; shift ;;
        --help|-h)
            cat <<'HELP'
Usage: ./run_game.sh [--build-only] [--editor] [--] [Godot arguments] [-- user arguments]

Build the Rust extension, then run the Godot diorama.
  --build-only  Build and copy the extension without starting Godot.
  --editor      Open the Godot editor after importing the project.

User arguments (after a second --): --seed=N --lut=off|auto|NAME|PATH.cube
  --strength=0..1 --compare=0|1|2 --cam=yaw,pitch,dist,fov[,fx,fy,fz]
  --size=WxH --capture=PATH --frames=N --vignette=0..1 --nohud
GODOT_BIN selects the Godot executable (default: godot); CARGO_FLAGS adds
cargo build flags (e.g. --offline).
HELP
            exit 0
            ;;
        --) shift; break ;;
        *) break ;;
    esac
done

cargo_bin=${CARGO:-cargo}
godot_bin=${GODOT_BIN:-godot}
cargo_flags=${CARGO_FLAGS:-}
"$cargo_bin" build --manifest-path "$project_root/godot_bridge/Cargo.toml" --release $cargo_flags \
    --target-dir "$project_root/target"
mkdir -p "$project_root/godot/bin"
extension="$project_root/godot/bin/libplatforms_test_godot.so"
cp -- "$project_root/target/release/libplatforms_test_godot.so" "$extension.tmp.$$"
mv -f -- "$extension.tmp.$$" "$extension"

if [ "$build_only" = true ]; then
    exit 0
fi
if [ ! -d "$project_root/godot/.godot" ] || [ "$editor" = true ]; then
    "$godot_bin" --headless --editor --import --frame-delay 800 --path "$project_root/godot" >/dev/null 2>&1 || true
fi
if [ "$editor" = true ]; then
    exec "$godot_bin" --path "$project_root/godot" --editor "$@"
fi
exec "$godot_bin" --path "$project_root/godot" "$@"
