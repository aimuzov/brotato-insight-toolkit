#!/usr/bin/env bash
# Копирует согласованные PNG 128×128 и собирает превью набора.
set -euo pipefail

cd "$(dirname "$0")"
OUT="../mods-unpacked/aimuzov-InsightToolkit/art/icons"
SOURCE="source/approved-icons"

command -v magick >/dev/null || { echo "ImageMagick is required" >&2; exit 1; }
mkdir -p "$OUT"
icons=()
for png in "$SOURCE"/*.png; do
	name=$(basename "$png")
	cp "$png" "$OUT/$name"
	icons+=("$OUT/$name")
done

magick \( "${icons[@]:0:8}" -background '#17221b' -alpha remove -alpha off -bordercolor '#17221b' -border 12 +append \) \
	\( "${icons[@]:8:8}" -background '#17221b' -alpha remove -alpha off -bordercolor '#17221b' -border 12 +append \) -append -strip preview.png
echo "Icons -> $OUT"
