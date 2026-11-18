#!/usr/bin/env bash
# Пересобирает иконки статов: SVG из make_icons.py -> PNG 96x96 в папке мода.
# GODOT — бинарник Godot 3.5 (растеризует SVG), нужен ImageMagick для уменьшения.
set -euo pipefail

cd "$(dirname "$0")"
: "${GODOT:?set GODOT to a Godot 3.5 binary}"

OUT="../mods-unpacked/aimuzov-InsightToolkit/art/icons"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

python3 make_icons.py
echo "config_version=4" > "$TMP/project.godot"
"$GODOT" --no-window --path "$TMP" -s "$PWD/svg_to_png.gd" "$PWD/icons" "$TMP/big" > /dev/null
mkdir -p "$OUT"
for png in "$TMP"/big/*.png; do
	magick "$png" -filter Lanczos -resize 96x96 "$OUT/$(basename "$png")"
done
echo "Icons -> $OUT"
