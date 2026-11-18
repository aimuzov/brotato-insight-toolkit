#!/usr/bin/env bash
# Собирает zip мода и подкладывает его в папку подписанного Workshop-мода.
# Steam-сборка ModLoader читает только папки подписок, локальную mods/ игнорирует,
# поэтому берём папку Oudstand-ModOptions. Обновление того мода может стереть zip —
# тогда просто запусти скрипт ещё раз.
#
# ICONS=revamped — только для локальной проверки: иконки статов берутся из скачанного
# RevampedIcons (monoSDE) во временную копию мода. В репозиторий и в публикацию они
# не попадают; перед публикацией собирай без этой переменной.
set -euo pipefail

cd "$(dirname "$0")"

MOD_ID="aimuzov-InsightToolkit"
WORKSHOP="$HOME/Library/Application Support/Steam/steamapps/workshop/content/1942280"
WORKSHOP_ITEM="${WORKSHOP_ITEM:-3598984651}"
OUT_DIR="${OUT_DIR:-$WORKSHOP/$WORKSHOP_ITEM}"
REVAMPED_ITEM="3003721761"
ICONS="${ICONS:-ours}"

[ -d "$OUT_DIR" ] || { echo "No such dir: $OUT_DIR" >&2; exit 1; }
if [[ "$OUT_DIR" == "$WORKSHOP/"* ]] && pgrep -x Brotato >/dev/null; then
	echo "Close Brotato before updating the installed mod" >&2
	exit 1
fi

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/mods-unpacked"
cp -R "mods-unpacked/$MOD_ID" "$STAGE/mods-unpacked/"

if [ "$ICONS" = "revamped" ]; then
	# Кеш в dist/ (он в .gitignore): после первой сборки подписка на мод уже не нужна
	cache="dist/revamped-icons"
	revamped_zip=$(ls "$WORKSHOP/$REVAMPED_ITEM"/*.zip 2>/dev/null | head -1 || true)
	if [ -n "$revamped_zip" ]; then
		rm -rf "$cache" "$STAGE/revamped"
		mkdir -p "$cache"
		unzip -qo "$revamped_zip" "mods-unpacked/monoSDE-RevampedIcons/overwrites/items/stats/*.png" -d "$STAGE/revamped"
		for png in "$STAGE"/revamped/mods-unpacked/monoSDE-RevampedIcons/overwrites/items/stats/monoSDE_*.png; do
			name=$(basename "$png" .png)
			cp "$png" "$cache/${name#monoSDE_}.png"
		done
	fi
	[ -n "$(ls "$cache" 2>/dev/null)" ] || { echo "No RevampedIcons: subscribe to it in Workshop once and rebuild" >&2; exit 1; }
	icons_dir="$STAGE/mods-unpacked/$MOD_ID/art/icons"
	cp "$cache"/*.png "$icons_dir/"
	echo "Local build: stat icons from RevampedIcons ($(ls "$cache" | wc -l | tr -d " ") files), do not publish"
fi

mkdir -p dist
rm -f "dist/$MOD_ID.zip"
(cd "$STAGE" && zip -qr "$OLDPWD/dist/$MOD_ID.zip" "mods-unpacked/$MOD_ID" -x "*.DS_Store")
cp "dist/$MOD_ID.zip" "$OUT_DIR/"

echo "Built dist/$MOD_ID.zip -> $OUT_DIR/"
