#!/usr/bin/env bash
# Перекрашивает исходные PNG, сохраняя альфа-канал и геометрию пиксель в пиксель.
set -euo pipefail

cd "$(dirname "$0")"
OUT="../mods-unpacked/aimuzov-InsightToolkit/art/icons"
SOURCE="source/revamped-icons"

command -v magick >/dev/null || { echo "ImageMagick is required" >&2; exit 1; }
mkdir -p "$OUT"
icons=()
while IFS=$'\t' read -r stat color; do
	magick "$SOURCE/$stat.png" -channel RGB -fill "$color" -colorize 100 +channel -strip "$OUT/$stat.png"
	icons+=("$OUT/$stat.png")
done < palette.tsv

magick \( "${icons[@]:0:8}" -background '#17221b' -alpha remove -alpha off -bordercolor '#17221b' -border 12 +append \) \
	\( "${icons[@]:8:8}" -background '#17221b' -alpha remove -alpha off -bordercolor '#17221b' -border 12 +append \) -append -strip preview.png
echo "Icons -> $OUT"
