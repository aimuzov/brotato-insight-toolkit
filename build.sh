#!/usr/bin/env bash
# Собирает zip мода и подкладывает его в папку подписанного Workshop-мода.
# Steam-сборка ModLoader читает только папки подписок, локальную mods/ игнорирует,
# поэтому берём папку Oudstand-ModOptions. Обновление того мода может стереть zip —
# тогда просто запусти скрипт ещё раз.
set -euo pipefail

cd "$(dirname "$0")"

MOD_ID="aimuzov-InsightToolkit"
WORKSHOP="$HOME/Library/Application Support/Steam/steamapps/workshop/content/1942280"
WORKSHOP_ITEM="${WORKSHOP_ITEM:-3598984651}"
OUT_DIR="${OUT_DIR:-$WORKSHOP/$WORKSHOP_ITEM}"

[ -d "$OUT_DIR" ] || { echo "No such dir: $OUT_DIR" >&2; exit 1; }
if [[ "$OUT_DIR" == "$WORKSHOP/"* ]] && pgrep -x Brotato >/dev/null; then
	echo "Close Brotato before updating the installed mod" >&2
	exit 1
fi

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/mods-unpacked"
cp -R "mods-unpacked/$MOD_ID" "$STAGE/mods-unpacked/"

mkdir -p dist
rm -f "dist/$MOD_ID.zip"
(cd "$STAGE" && zip -qr "$OLDPWD/dist/$MOD_ID.zip" "mods-unpacked/$MOD_ID" -x "*.DS_Store")
cp "dist/$MOD_ID.zip" "$OUT_DIR/"

echo "Built dist/$MOD_ID.zip -> $OUT_DIR/"
